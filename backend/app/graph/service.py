from __future__ import annotations

import hashlib
import json
import re
from collections import defaultdict, deque
from collections.abc import Callable
from itertools import combinations
from typing import Any
from uuid import uuid4

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core.event_bus.bus import DomainEvent
from app.core.logging.service import logger
from app.core.search.index import SearchDocument, index
from app.core.analytics.metrics import metrics
from app.graph.models import GraphNodeModel, GraphRelationshipModel, GraphSuggestionModel
from app.graph.schemas import DuplicateGroup, GraphContext, GraphInsight, GraphNodeRead, GraphPathResponse, GraphSearchResponse, GraphStats, GraphSuggestionRead, RelationshipRead
from app.core.utils.common import utcnow

utc_now = utcnow


def node_key(workspace_id: str, entity_type: str, entity_id: str) -> str:
    scope = workspace_id.strip() or '_global'
    return f'{scope}:{entity_type.strip().lower()}:{entity_id.strip()}'


def _json(value: Any, fallback: Any) -> str:
    try:
        return json.dumps(value if value is not None else fallback, ensure_ascii=False, sort_keys=True, default=str)
    except (TypeError, ValueError):
        return json.dumps(fallback)


def _loads(value: str, fallback: Any) -> Any:
    try:
        return json.loads(value)
    except (TypeError, ValueError, json.JSONDecodeError):
        return fallback


def _tokens(value: str) -> set[str]:
    return {token for token in re.findall(r'[\w]{2,}', value.casefold()) if token not in {'the', 'and', 'for', 'with', 'from', 'this', 'that'}}


def _jaccard(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def _node_read(node: GraphNodeModel) -> GraphNodeRead:
    return GraphNodeRead(
        id=node.id,
        entity_type=node.entity_type,
        entity_id=node.entity_id,
        workspace_id=node.workspace_id,
        label=node.label,
        content_text=node.content_text,
        tags=_loads(node.tags_json, []),
        metadata=_loads(node.metadata_json, {}),
        active=node.active,
        degree=node.degree_cache,
        created_at=node.created_at,
        updated_at=node.updated_at,
    )


def _relationship_read(relationship: GraphRelationshipModel) -> RelationshipRead:
    return RelationshipRead(
        id=relationship.id,
        workspace_id=relationship.workspace_id,
        source_node_id=relationship.source_node_id,
        target_node_id=relationship.target_node_id,
        relationship_type=relationship.relationship_type,
        weight=relationship.weight,
        confidence=relationship.confidence,
        explanation=relationship.explanation,
        source=relationship.source,
        metadata=_loads(relationship.metadata_json, {}),
        created_at=relationship.created_at,
        updated_at=relationship.updated_at,
    )


def _suggestion_read(suggestion: GraphSuggestionModel) -> GraphSuggestionRead:
    return GraphSuggestionRead.model_validate(suggestion, from_attributes=True)


class GraphService:
    def upsert_node(self, db: Session, *, entity_type: str, entity_id: str, workspace_id: str = '', label: str = '', content_text: str = '', tags: list[str] | None = None, metadata: dict[str, Any] | None = None, active: bool = True) -> GraphNodeModel:
        normalized_type = entity_type.strip().lower()
        normalized_id = entity_id.strip()
        normalized_workspace = workspace_id.strip()
        node = db.scalar(select(GraphNodeModel).where(GraphNodeModel.workspace_id == normalized_workspace, GraphNodeModel.entity_type == normalized_type, GraphNodeModel.entity_id == normalized_id))
        if node is None:
            node = GraphNodeModel(id=node_key(normalized_workspace, normalized_type, normalized_id), workspace_id=normalized_workspace, entity_type=normalized_type, entity_id=normalized_id)
            db.add(node)
        node.label = (label or node.label or f'{normalized_type.title()} {normalized_id}')[:240]
        node.content_text = content_text[:200_000]
        node.tags_json = _json(sorted({str(tag).strip() for tag in (tags or []) if str(tag).strip()}), [])
        node.metadata_json = _json(metadata or {}, {})
        node.active = active
        node.updated_at = utc_now()
        index.upsert(SearchDocument(
            document_id=node.id,
            title=node.label,
            text=' '.join([node.content_text, ' '.join(_loads(node.tags_json, []))]),
            source_type=node.entity_type,
            metadata={'workspace_id': node.workspace_id, 'entity_type': node.entity_type, 'entity_id': node.entity_id},
        ))
        return node

    def get_node(self, db: Session, node_id: str, workspace_id: str = '') -> GraphNodeModel | None:
        statement = select(GraphNodeModel).where(GraphNodeModel.id == node_id)
        if workspace_id:
            statement = statement.where(GraphNodeModel.workspace_id == workspace_id)
        return db.scalar(statement)

    def delete_node(self, db: Session, node_id: str, workspace_id: str = '') -> bool:
        node = self.get_node(db, node_id, workspace_id)
        if node is None:
            return False
        db.query(GraphRelationshipModel).filter(or_(GraphRelationshipModel.source_node_id == node_id, GraphRelationshipModel.target_node_id == node_id)).delete(synchronize_session=False)
        node.active = False
        node.degree_cache = 0
        node.updated_at = utc_now()
        index.remove(node_id)
        return True

    def list_nodes(self, db: Session, workspace_id: str = '', entity_type: str | None = None, query: str | None = None, limit: int = 100) -> list[GraphNodeModel]:
        statement = select(GraphNodeModel).where(GraphNodeModel.workspace_id == workspace_id, GraphNodeModel.active.is_(True)).order_by(GraphNodeModel.updated_at.desc()).limit(min(max(limit, 1), 500))
        if entity_type:
            statement = statement.where(GraphNodeModel.entity_type == entity_type.strip().lower())
        if query:
            needle = f'%{query.strip()}%'
            statement = statement.where(or_(GraphNodeModel.label.ilike(needle), GraphNodeModel.content_text.ilike(needle), GraphNodeModel.tags_json.ilike(needle)))
        return list(db.scalars(statement).all())

    def ensure_relationship(self, db: Session, *, workspace_id: str, source_node_id: str, target_node_id: str, relationship_type: str, weight: float = 1.0, confidence: float = 1.0, explanation: str = '', source: str = 'manual', metadata: dict[str, Any] | None = None) -> GraphRelationshipModel:
        if source_node_id == target_node_id:
            raise ValueError('A graph relationship cannot connect a node to itself')
        db.flush()
        source_node = self.get_node(db, source_node_id, workspace_id)
        target_node = self.get_node(db, target_node_id, workspace_id)
        if source_node is None or target_node is None:
            raise ValueError('Both relationship nodes must exist in the same workspace')
        normalized_type = relationship_type.strip().lower().replace(' ', '_')[:80]
        relationship = db.scalar(select(GraphRelationshipModel).where(GraphRelationshipModel.workspace_id == workspace_id, GraphRelationshipModel.source_node_id == source_node_id, GraphRelationshipModel.target_node_id == target_node_id, GraphRelationshipModel.relationship_type == normalized_type))
        if relationship is None:
            relationship = GraphRelationshipModel(id=str(uuid4()), workspace_id=workspace_id, source_node_id=source_node_id, target_node_id=target_node_id, relationship_type=normalized_type)
            db.add(relationship)
            source_node.degree_cache += 1
            target_node.degree_cache += 1
        relationship.weight = weight
        relationship.confidence = confidence
        relationship.explanation = explanation[:1_000]
        relationship.source = source[:32]
        relationship.metadata_json = _json(metadata or {}, {})
        relationship.updated_at = utc_now()
        return relationship

    def remove_relationship(self, db: Session, relationship_id: str, workspace_id: str = '') -> bool:
        statement = select(GraphRelationshipModel).where(GraphRelationshipModel.id == relationship_id)
        if workspace_id:
            statement = statement.where(GraphRelationshipModel.workspace_id == workspace_id)
        relationship = db.scalar(statement)
        if relationship is None:
            return False
        for node_id in (relationship.source_node_id, relationship.target_node_id):
            node = self.get_node(db, node_id, relationship.workspace_id)
            if node is not None:
                node.degree_cache = max(0, node.degree_cache - 1)
        db.delete(relationship)
        return True

    def list_relationships(self, db: Session, workspace_id: str = '', node_id: str | None = None, relationship_type: str | None = None, limit: int = 200) -> list[GraphRelationshipModel]:
        statement = select(GraphRelationshipModel).where(GraphRelationshipModel.workspace_id == workspace_id).order_by(GraphRelationshipModel.updated_at.desc()).limit(min(max(limit, 1), 1_000))
        if node_id:
            statement = statement.where(or_(GraphRelationshipModel.source_node_id == node_id, GraphRelationshipModel.target_node_id == node_id))
        if relationship_type:
            statement = statement.where(GraphRelationshipModel.relationship_type == relationship_type.strip().lower().replace(' ', '_'))
        return list(db.scalars(statement).all())

    def context(self, db: Session, node_id: str, workspace_id: str = '') -> GraphContext | None:
        node = self.get_node(db, node_id, workspace_id)
        if node is None:
            return None
        incoming = list(db.scalars(select(GraphRelationshipModel).where(GraphRelationshipModel.workspace_id == node.workspace_id, GraphRelationshipModel.target_node_id == node.id)).all())
        outgoing = list(db.scalars(select(GraphRelationshipModel).where(GraphRelationshipModel.workspace_id == node.workspace_id, GraphRelationshipModel.source_node_id == node.id)).all())
        related_ids = {item.source_node_id for item in incoming} | {item.target_node_id for item in outgoing}
        related_ids.discard(node.id)
        related = list(db.scalars(select(GraphNodeModel).where(GraphNodeModel.workspace_id == node.workspace_id, GraphNodeModel.id.in_(related_ids), GraphNodeModel.active.is_(True))).all()) if related_ids else []
        suggestions = list(db.scalars(select(GraphSuggestionModel).where(GraphSuggestionModel.workspace_id == node.workspace_id, GraphSuggestionModel.status == 'pending', or_(GraphSuggestionModel.source_node_id == node.id, GraphSuggestionModel.target_node_id == node.id)).order_by(GraphSuggestionModel.score.desc()).limit(25)).all())
        return GraphContext(node=_node_read(node), incoming=[_relationship_read(item) for item in incoming], outgoing=[_relationship_read(item) for item in outgoing], related=[_node_read(item) for item in related], suggestions=[_suggestion_read(item) for item in suggestions])

    def search(self, db: Session, query: str, workspace_id: str = '', limit: int = 50) -> GraphSearchResponse:
        query_tokens = _tokens(query)
        nodes = self.list_nodes(db, workspace_id, query=query, limit=min(limit * 4, 500))
        scored: list[tuple[float, GraphNodeModel]] = []
        for node in nodes:
            text_tokens = _tokens(' '.join([node.label, node.content_text, ' '.join(_loads(node.tags_json, []))]))
            score = _jaccard(query_tokens, text_tokens) if query_tokens else 0.0
            if query.casefold() in node.label.casefold():
                score += 1.0
            scored.append((score, node))
        scored.sort(key=lambda item: (item[0], item[1].updated_at), reverse=True)
        result_nodes = [node for _, node in scored[:limit]]
        relationships = self.list_relationships(db, workspace_id, limit=limit) if not result_nodes else self.list_relationships(db, workspace_id, node_id=None, limit=limit)
        return GraphSearchResponse(query=query, nodes=[_node_read(node) for node in result_nodes], relationships=[_relationship_read(item) for item in relationships])

    def path(self, db: Session, source_node_id: str, target_node_id: str, workspace_id: str = '', max_depth: int = 8) -> GraphPathResponse:
        if source_node_id == target_node_id:
            return GraphPathResponse(source_node_id=source_node_id, target_node_id=target_node_id, node_ids=[source_node_id], relationships=[], found=True)
        relationships = self.list_relationships(db, workspace_id, limit=100_000)
        adjacency: dict[str, list[GraphRelationshipModel]] = defaultdict(list)
        for relationship in relationships:
            adjacency[relationship.source_node_id].append(relationship)
            adjacency[relationship.target_node_id].append(relationship)
        queue: deque[tuple[str, list[str], list[GraphRelationshipModel]]] = deque([(source_node_id, [source_node_id], [])])
        visited = {source_node_id}
        while queue:
            current, node_ids, path_relationships = queue.popleft()
            if len(path_relationships) >= max_depth:
                continue
            for relationship in adjacency.get(current, []):
                next_node = relationship.target_node_id if relationship.source_node_id == current else relationship.source_node_id
                if next_node in visited:
                    continue
                next_nodes = [*node_ids, next_node]
                next_relationships = [*path_relationships, relationship]
                if next_node == target_node_id:
                    return GraphPathResponse(source_node_id=source_node_id, target_node_id=target_node_id, node_ids=next_nodes, relationships=[_relationship_read(item) for item in next_relationships], found=True)
                visited.add(next_node)
                queue.append((next_node, next_nodes, next_relationships))
        return GraphPathResponse(source_node_id=source_node_id, target_node_id=target_node_id, node_ids=[], relationships=[], found=False)

    def stats(self, db: Session, workspace_id: str = '') -> GraphStats:
        nodes = list(db.scalars(select(GraphNodeModel).where(GraphNodeModel.workspace_id == workspace_id, GraphNodeModel.active.is_(True))).all())
        relationships = self.list_relationships(db, workspace_id, limit=100_000)
        type_counts = dict(db.execute(select(GraphRelationshipModel.relationship_type, func.count(GraphRelationshipModel.id)).where(GraphRelationshipModel.workspace_id == workspace_id).group_by(GraphRelationshipModel.relationship_type)).all())
        adjacency: dict[str, set[str]] = defaultdict(set)
        for relationship in relationships:
            adjacency[relationship.source_node_id].add(relationship.target_node_id)
            adjacency[relationship.target_node_id].add(relationship.source_node_id)
        components = 0
        unseen = {node.id for node in nodes}
        while unseen:
            components += 1
            stack = [unseen.pop()]
            while stack:
                for neighbor in adjacency.get(stack.pop(), set()):
                    if neighbor in unseen:
                        unseen.remove(neighbor)
                        stack.append(neighbor)
        node_count = len(nodes)
        possible = node_count * max(0, node_count - 1)
        density = round(len(relationships) / possible, 6) if possible else 0.0
        accepted = db.scalar(select(func.count(GraphSuggestionModel.id)).where(GraphSuggestionModel.workspace_id == workspace_id, GraphSuggestionModel.status == 'accepted')) or 0
        return GraphStats(workspace_id=workspace_id, total_nodes=node_count, active_nodes=node_count, total_relationships=len(relationships), relationship_types=type_counts, graph_density=density, connected_components=components, orphaned_nodes=sum(1 for node in nodes if not adjacency.get(node.id)), accepted_suggestions=int(accepted))

    def suggestions(self, db: Session, workspace_id: str = '', limit: int = 50) -> list[GraphSuggestionModel]:
        nodes = self.list_nodes(db, workspace_id, limit=250)
        existing = {(item.source_node_id, item.target_node_id, item.relationship_type) for item in self.list_relationships(db, workspace_id, limit=100_000)}
        candidates: list[tuple[float, GraphNodeModel, GraphNodeModel, str, str]] = []
        for left, right in combinations(nodes, 2):
            left_tags = set(_loads(left.tags_json, []))
            right_tags = set(_loads(right.tags_json, []))
            shared_tags = left_tags & right_tags
            content_score = _jaccard(_tokens(left.content_text), _tokens(right.content_text))
            tag_score = _jaccard(left_tags, right_tags)
            left_meta = _loads(left.metadata_json, {})
            right_meta = _loads(right.metadata_json, {})
            shared_context = [key for key in ('project_id', 'goal_id', 'topic') if left_meta.get(key) and left_meta.get(key) == right_meta.get(key)]
            score = min(1.0, content_score * 0.65 + tag_score * 0.25 + (0.1 if shared_context else 0.0))
            reasons: list[str] = []
            if content_score >= 0.2:
                reasons.append(f'{round(content_score * 100)}% shared content terms')
            if shared_tags:
                reasons.append(f'shared tags: {", ".join(sorted(shared_tags)[:4])}')
            if shared_context:
                reasons.append(f'shared context: {", ".join(shared_context)}')
            if score < 0.28 or not reasons:
                continue
            relationship_type = 'similar_to' if content_score >= tag_score else 'related_to'
            if (left.id, right.id, relationship_type) in existing or (right.id, left.id, relationship_type) in existing:
                continue
            candidates.append((score, left, right, relationship_type, 'Suggested because ' + '; '.join(reasons) + '.'))
        candidates.sort(key=lambda item: item[0], reverse=True)
        results: list[GraphSuggestionModel] = []
        for score, left, right, relationship_type, explanation in candidates[:min(limit, 100)]:
            suggestion = db.scalar(select(GraphSuggestionModel).where(GraphSuggestionModel.workspace_id == workspace_id, GraphSuggestionModel.source_node_id == left.id, GraphSuggestionModel.target_node_id == right.id, GraphSuggestionModel.relationship_type == relationship_type))
            if suggestion is None:
                suggestion = GraphSuggestionModel(id=str(uuid4()), workspace_id=workspace_id, source_node_id=left.id, target_node_id=right.id, relationship_type=relationship_type)
                db.add(suggestion)
            if suggestion.status == 'pending':
                suggestion.score = score
                suggestion.explanation = explanation
                suggestion.updated_at = utc_now()
            results.append(suggestion)
        metrics.increment('graph.suggestions.generated', len(results))
        return results

    def accept_suggestion(self, db: Session, suggestion_id: str, workspace_id: str = '') -> GraphRelationshipModel | None:
        statement = select(GraphSuggestionModel).where(GraphSuggestionModel.id == suggestion_id)
        if workspace_id:
            statement = statement.where(GraphSuggestionModel.workspace_id == workspace_id)
        suggestion = db.scalar(statement)
        if suggestion is None:
            return None
        relationship = self.ensure_relationship(db, workspace_id=suggestion.workspace_id, source_node_id=suggestion.source_node_id, target_node_id=suggestion.target_node_id, relationship_type=suggestion.relationship_type, confidence=suggestion.score, explanation=suggestion.explanation, source='ai_suggestion')
        suggestion.status = 'accepted'
        suggestion.updated_at = utc_now()
        metrics.increment('graph.suggestions.accepted')
        return relationship

    def insights(self, db: Session, workspace_id: str = '') -> list[GraphInsight]:
        nodes = self.list_nodes(db, workspace_id, limit=500)
        stats = self.stats(db, workspace_id)
        insights: list[GraphInsight] = []
        connected = sorted(nodes, key=lambda node: node.degree_cache, reverse=True)[:5]
        if connected and connected[0].degree_cache > 0:
            insights.append(GraphInsight(insight_type='most_connected', title='Most connected knowledge', explanation='These items have the highest number of direct graph relationships.', node_ids=[node.id for node in connected], score=float(connected[0].degree_cache)))
        orphaned = [node for node in nodes if node.degree_cache == 0]
        if orphaned:
            insights.append(GraphInsight(insight_type='orphaned_items', title='Orphaned items', explanation='These active items have no incoming or outgoing relationships yet.', node_ids=[node.id for node in orphaned[:25]], score=float(len(orphaned))))
        if stats.total_nodes > 1 and stats.total_relationships == 0:
            insights.append(GraphInsight(insight_type='missing_relationships', title='Add first connections', explanation='The workspace has multiple graph items but no relationships; link projects, tasks, notes, and assets to make context discoverable.', node_ids=[node.id for node in nodes[:10]], score=1.0))
        return insights

    def duplicates(self, db: Session, workspace_id: str = '', limit: int = 50) -> list[DuplicateGroup]:
        nodes = self.list_nodes(db, workspace_id, limit=300)
        groups: list[DuplicateGroup] = []
        seen: set[str] = set()
        for left, right in combinations(nodes, 2):
            if left.id in seen and right.id in seen:
                continue
            left_meta = _loads(left.metadata_json, {})
            right_meta = _loads(right.metadata_json, {})
            same_hash = left_meta.get('content_hash') and left_meta.get('content_hash') == right_meta.get('content_hash')
            same_label = left.label.strip().casefold() and left.label.strip().casefold() == right.label.strip().casefold()
            similarity = _jaccard(_tokens(left.content_text), _tokens(right.content_text))
            if not (same_hash or same_label or similarity >= 0.85):
                continue
            reason = 'same_content_hash' if same_hash else 'same_label' if same_label else 'similar_content'
            score = 1.0 if same_hash or same_label else similarity
            groups.append(DuplicateGroup(reason=reason, node_ids=[left.id, right.id], explanation='These items may represent duplicate knowledge. Review before merging; no data was deleted automatically.', score=round(score, 3)))
            seen.update((left.id, right.id))
            if len(groups) >= limit:
                break
        return groups

    def sync_event(self, db: Session, event: DomainEvent) -> None:
        name = event.name
        payload = dict(event.payload or {})
        if name in {'relationship.added', 'relationship.created'}:
            source = str(payload.get('source_node_id', ''))
            target = str(payload.get('target_node_id', ''))
            if source and target:
                self.ensure_relationship(db, workspace_id=str(payload.get('workspace_id', '')), source_node_id=source, target_node_id=target, relationship_type=str(payload.get('relationship_type', 'related_to')), explanation=str(payload.get('explanation', 'Created from a domain event.')), source='event')
            return
        if name in {'relationship.removed', 'relationship.deleted'}:
            relationship_id = str(payload.get('relationship_id', ''))
            if relationship_id:
                self.remove_relationship(db, relationship_id, str(payload.get('workspace_id', '')))
            return
        suffix = name.rsplit('.', 1)[-1] if '.' in name else ''
        if suffix not in {'created', 'updated', 'completed', 'processed', 'archived', 'deleted'}:
            return
        entity_type = str(payload.get('entity_type') or name.split('.')[0]).replace('project', 'project').strip().lower()
        entity_id = str(payload.get(f'{entity_type}_id') or payload.get('entity_id') or payload.get('id') or '')
        if not entity_id:
            return
        workspace_id = str(payload.get('workspace_id') or '')
        active = suffix not in {'archived', 'deleted'}
        label = str(payload.get('label') or payload.get('title') or f'{entity_type.title()} {entity_id}')
        node = self.upsert_node(db, entity_type=entity_type, entity_id=entity_id, workspace_id=workspace_id, label=label, content_text=str(payload.get('content_text') or payload.get('description') or ''), tags=list(payload.get('tags') or []), metadata=payload, active=active)
        for related_type, related_id in (('workspace', workspace_id), ('project', payload.get('project_id')), ('goal', payload.get('goal_id'))):
            if not related_id or related_type == entity_type:
                continue
            related = self.upsert_node(db, entity_type=related_type, entity_id=str(related_id), workspace_id=workspace_id, label=f'{related_type.title()} {related_id}', metadata={})
            self.ensure_relationship(db, workspace_id=workspace_id, source_node_id=node.id, target_node_id=related.id, relationship_type='belongs_to', explanation=f'{entity_type.title()} is linked to its {related_type}.', source='event')
        if entity_type == 'milestone' and payload.get('project_id'):
            project = self.upsert_node(db, entity_type='project', entity_id=str(payload['project_id']), workspace_id=workspace_id, label=f'Project {payload["project_id"]}', metadata={})
            self.ensure_relationship(db, workspace_id=workspace_id, source_node_id=node.id, target_node_id=project.id, relationship_type='belongs_to', explanation='Milestone belongs to project.', source='event')


service = GraphService()
_graph_session_factory: Callable[[], Session] | None = None


def _handle_graph_event(event: DomainEvent) -> None:
    if _graph_session_factory is None:
        return
    db = _graph_session_factory()
    try:
        service.sync_event(db, event)
        db.commit()
    except Exception as exc:  # pragma: no cover - defensive event boundary
        db.rollback()
        logger.error('Graph event synchronization failed', event=event.name, error=str(exc))
    finally:
        db.close()


def attach_graph_event_handlers(event_bus: object, session_factory: Callable[[], Session]) -> None:
    global _graph_session_factory
    _graph_session_factory = session_factory
    event_bus.subscribe('*', _handle_graph_event)
