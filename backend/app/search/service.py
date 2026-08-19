from __future__ import annotations

import hashlib
import json
import re
import time
from collections import Counter, defaultdict
from datetime import timedelta
from difflib import SequenceMatcher
from typing import Any
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.analytics.metrics import metrics
from app.core.ai import ai_engine
from app.core.logging.service import logger
from app.core.search.index import SearchDocument, SearchHit, index
from app.core.utils.common import normalize_text, tokenize, utcnow
from app.graph.models import GraphNodeModel, GraphRelationshipModel
from app.graph.service import service as graph_service
from app.search.models import SavedSearchModel, SearchHistoryModel, SmartCollectionModel, StudyResourceModel
from app.search.schemas import CommandItem, CommandExecutionResult, DiscoveryResponse, KnowledgePathResponse, SearchFilters, SearchIntent, SearchResponse, SearchResult, SmartCollectionRead, StudyResourceRead


_SOURCE_TYPE_MAP = {
    'task': ('task',),
    'tasks': ('task',),
    'calendar': ('calendar_event', 'event'),
    'event': ('calendar_event', 'event'),
    'project': ('project',),
    'projects': ('project',),
    'goal': ('goal',),
    'goals': ('goal',),
    'note': ('note',),
    'notes': ('note',),
    'asset': ('asset',),
    'assets': ('asset',),
    'pdf': ('pdf', 'asset'),
    'docx': ('docx', 'asset'),
    'ppt': ('ppt', 'asset'),
    'markdown': ('markdown', 'asset'),
    'voice': ('voice_note', 'asset'),
    'ocr': ('ocr_document', 'asset'),
    'image': ('image', 'asset'),
    'url': ('url', 'asset'),
    'paper': ('research_paper', 'asset'),
    'research': ('research_paper', 'asset'),
    'conversation': ('assistant_conversation',),
    'workspace': ('workspace',),
    'collection': ('collection',),
    'reminder': ('reminder',),
    'settings': ('setting',),
    'automation': ('automation',),
    'analytics': ('analytics',),
}


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
    return set(tokenize(normalize_text(value)))


def _content_hash(title: str, text: str) -> str:
    return hashlib.sha256(normalize_text(f'{title}\n{text}').encode('utf-8')).hexdigest()


def _hit_result(hit: SearchHit, related_item_ids: list[str] | None = None) -> SearchResult:
    metadata = dict(hit.metadata or {})
    snippet = hit.snippet or ''
    actions = ['open']
    if hit.source_type in {'task', 'note', 'asset', 'project', 'reminder'}:
        actions.extend(['create_task', 'create_reminder'])
    return SearchResult(
        document_id=hit.document_id,
        title=hit.title,
        score=round(hit.score, 5),
        snippet=snippet,
        source_type=hit.source_type,
        source_url=hit.source_url,
        metadata=metadata,
        preview=snippet[:320],
        thumbnail_url=str(metadata.get('thumbnail_url', '')),
        summary=str(metadata.get('summary', '')),
        related_item_ids=related_item_ids or list(metadata.get('related_item_ids', [])),
        ai_insights=list(metadata.get('ai_insights', [])),
        quick_actions=actions,
    )


class SearchService:
    def interpret(self, query: str, filters: SearchFilters | None = None) -> SearchIntent:
        original = query.strip()
        lowered = original.casefold()
        parsed = filters.model_copy(deep=True) if filters else SearchFilters()
        entity_type = ''
        for term, source_types in _SOURCE_TYPE_MAP.items():
            if re.search(rf'\b{re.escape(term)}\b', lowered):
                entity_type = source_types[0]
                if not parsed.source_types:
                    parsed.source_types = list(source_types)
                break
        if 'this week' in lowered or 'recent' in lowered or 'lately' in lowered:
            parsed.recent_only = True
            parsed.date_from = utcnow() - timedelta(days=7)
        project_match = re.search(r'project\s+([\w-]+)', lowered)
        if project_match and project_match.group(1) not in {'about', 'with', 'from'}:
            parsed.project_id = project_match.group(1)
        intent = 'search'
        if any(term in lowered for term in ('summarize', 'summary', 'revision notes', 'cheat sheet', 'flashcard', 'quiz', 'formula', 'definition', 'study')):
            intent = 'study'
        elif any(term in lowered for term in ('where did i store', 'what am i working on', 'show me', 'find all', 'related')):
            intent = 'discovery'
        normalized = re.sub(r'\b(show|find|all|where did i store|what am i working on|please)\b', ' ', original, flags=re.IGNORECASE)
        normalized = normalize_text(normalized)
        explanation = 'Parsed keyword and workspace-friendly filters from the query.'
        if parsed.source_types:
            explanation += f' Source type filter: {", ".join(parsed.source_types)}.'
        if parsed.recent_only:
            explanation += ' Recent or this-week items are prioritized.'
        return SearchIntent(intent=intent, normalized_query=normalized or original, entity_type=entity_type, filters=parsed, explanation=explanation)

    def hydrate_index(self, db: Session, workspace_id: str = '') -> int:
        count = 0
        node_statement = select(GraphNodeModel).where(GraphNodeModel.active.is_(True))
        if workspace_id:
            node_statement = node_statement.where(GraphNodeModel.workspace_id == workspace_id)
        for node in db.scalars(node_statement).all():
            index.upsert(SearchDocument(document_id=node.id, title=node.label, text=' '.join([node.content_text, ' '.join(_loads(node.tags_json, []))]), source_type=node.entity_type, metadata={'workspace_id': node.workspace_id, 'entity_type': node.entity_type, 'entity_id': node.entity_id, 'project_id': _loads(node.metadata_json, {}).get('project_id', ''), 'tags': _loads(node.tags_json, []), 'updated_at': node.updated_at.isoformat() if node.updated_at else ''}))
            count += 1
        count += self._hydrate_model(db, workspace_id, 'task', 'app.models.task', 'TaskModel', ('title', 'description', 'workspace_id', 'project_id', 'goal_id', 'status', 'priority', 'tags', 'updated_at'))
        count += self._hydrate_model(db, workspace_id, 'calendar_event', 'app.calendar.models', 'EventModel', ('title', 'description', 'workspace_id', 'project_id', 'start_at', 'updated_at'))
        count += self._hydrate_model(db, workspace_id, 'note', 'app.notes.models', 'NoteModel', ('title', 'workspace_id', 'project_id', 'updated_at', 'archived'))
        count += self._hydrate_model(db, workspace_id, 'asset', 'app.assets.models', 'AssetModel', ('name', 'description', 'workspace_id', 'project_id', 'asset_type', 'preview_text', 'ocr_text', 'tags', 'modified_at', 'favorite'))
        count += self._hydrate_model(db, workspace_id, 'reminder', 'app.reminders.models', 'ReminderRecordModel', ('title', 'description', 'workspace_id', 'project_id', 'goal_id', 'category', 'ai_generated', 'modified_at', 'status'))
        count += self._hydrate_model(db, workspace_id, 'project', 'app.organization.models', 'ProjectModel', ('name', 'description', 'workspace_id', 'status', 'priority', 'progress', 'updated_at'))
        count += self._hydrate_model(db, workspace_id, 'goal', 'app.organization.models', 'GoalModel', ('title', 'description', 'workspace_id', 'goal_type', 'progress', 'updated_at'))
        count += self._hydrate_model(db, '', 'assistant_conversation', 'app.assistant.models', 'AssistantConversationModel', ('title', 'scope', 'updated_at'))
        return count

    def _hydrate_model(self, db: Session, workspace_id: str, source_type: str, module_name: str, class_name: str, fields: tuple[str, ...]) -> int:
        try:
            module = __import__(module_name, fromlist=[class_name])
            model = getattr(module, class_name)
        except (ImportError, AttributeError):
            return 0
        try:
            rows = db.scalars(select(model)).all()
        except Exception:
            return 0
        count = 0
        for row in rows:
            row_workspace = str(getattr(row, 'workspace_id', '') or '')
            if workspace_id and row_workspace not in {'', workspace_id}:
                continue
            identifier = str(getattr(row, 'id', '') or '')
            if not identifier:
                continue
            title = str(getattr(row, 'title', None) or getattr(row, 'name', None) or f'{source_type.title()} {identifier}')
            text_parts: list[str] = []
            metadata: dict[str, Any] = {'workspace_id': row_workspace, 'entity_type': source_type, 'entity_id': identifier}
            for field in fields:
                value = getattr(row, field, None)
                if value is None:
                    continue
                if field in {'title', 'name'}:
                    continue
                if isinstance(value, (str, int, float, bool)):
                    text_parts.append(str(value))
                    metadata[field] = value
                elif isinstance(value, list):
                    text_parts.extend(str(item) for item in value)
                    metadata[field] = value
                elif isinstance(value, dict):
                    text_parts.extend(str(item) for item in value.values())
                    metadata[field] = value
                elif hasattr(value, 'isoformat'):
                    metadata[field] = value.isoformat()
            metadata['content_hash'] = _content_hash(title, ' '.join(text_parts))
            index.upsert(SearchDocument(document_id=f'{row_workspace or "_global"}:{source_type}:{identifier}', title=title, text=' '.join(text_parts), source_type=source_type, metadata=metadata))
            count += 1
        return count

    def _matches_filters(self, hit: SearchHit, filters: SearchFilters) -> bool:
        metadata = hit.metadata or {}
        workspace = str(metadata.get('workspace_id', ''))
        if filters.workspace_id and workspace not in {'', filters.workspace_id}:
            return False
        if filters.project_id and str(metadata.get('project_id', '')) != filters.project_id:
            return False
        if filters.source_types and hit.source_type not in set(filters.source_types):
            return False
        if filters.category and str(metadata.get('category', '')).casefold() != filters.category.casefold():
            return False
        if filters.author and str(metadata.get('author', '')).casefold() != filters.author.casefold():
            return False
        if filters.file_type and str(metadata.get('file_type', '')).casefold() != filters.file_type.casefold():
            return False
        if filters.ai_generated is not None and bool(metadata.get('ai_generated', False)) != filters.ai_generated:
            return False
        if filters.favorite is not None and bool(metadata.get('favorite', False)) != filters.favorite:
            return False
        hit_tags = {str(tag).casefold() for tag in metadata.get('tags', [])}
        if filters.tags and not {tag.casefold() for tag in filters.tags}.issubset(hit_tags):
            return False
        updated = metadata.get('updated_at') or metadata.get('modified_at')
        if filters.date_from or filters.date_to or filters.recent_only:
            try:
                updated_at = __import__('datetime').datetime.fromisoformat(str(updated))
            except (ValueError, TypeError):
                updated_at = None
            if updated_at is None:
                return not filters.recent_only
            if filters.date_from and updated_at < filters.date_from:
                return False
            if filters.date_to and updated_at > filters.date_to:
                return False
            if filters.recent_only and updated_at < utcnow() - timedelta(days=30):
                return False
        return True

    def search(self, db: Session, query: str, filters: SearchFilters | None = None, search_type: str = 'keyword', limit: int = 50, record_history: bool = True) -> SearchResponse:
        started = time.perf_counter()
        intent = self.interpret(query, filters)
        active_filters = intent.filters
        if search_type == 'ai':
            search_type = 'semantic'
        self.hydrate_index(db, active_filters.workspace_id)
        raw_hits = index.search(intent.normalized_query, limit=min(limit * 5, 200))
        filtered = [hit for hit in raw_hits if self._matches_filters(hit, active_filters)]
        if not filtered:
            query_tokens = _tokens(intent.normalized_query)
            for document_id, document in list(index._documents.items()):
                if active_filters.workspace_id and document.metadata.get('workspace_id', '') not in {'', active_filters.workspace_id}:
                    continue
                similarity = SequenceMatcher(None, intent.normalized_query.casefold(), document.title.casefold()).ratio()
                if similarity >= 0.45 and query_tokens:
                    filtered.append(SearchHit(document_id, document.title, similarity, document.normalized_text[:220], document.source_type, document.source_url, document.metadata))
            filtered.sort(key=lambda hit: hit.score, reverse=True)
        results = [_hit_result(hit) for hit in filtered[:limit]]
        took_ms = round((time.perf_counter() - started) * 1000, 3)
        metrics.observe_ms('search.duration_ms', took_ms)
        metrics.increment('search.requests')
        if record_history:
            history = SearchHistoryModel(id=str(uuid4()), workspace_id=active_filters.workspace_id, query=query[:500], search_type=search_type, result_count=len(results))
            db.add(history)
            db.commit()
        return SearchResponse(query=query, search_type=search_type, intent=intent.intent, results=results, total=len(results), took_ms=took_ms)

    def history(self, db: Session, workspace_id: str = '', limit: int = 20) -> list[SearchHistoryModel]:
        statement = select(SearchHistoryModel).where(SearchHistoryModel.workspace_id == workspace_id).order_by(SearchHistoryModel.created_at.desc()).limit(min(max(limit, 1), 100))
        return list(db.scalars(statement).all())

    def saved_searches(self, db: Session, workspace_id: str = '') -> list[SavedSearchModel]:
        return list(db.scalars(select(SavedSearchModel).where(SavedSearchModel.workspace_id == workspace_id).order_by(SavedSearchModel.favorite.desc(), SavedSearchModel.updated_at.desc())).all())

    def discovery(self, db: Session, source_id: str, workspace_id: str = '') -> DiscoveryResponse:
        context = graph_service.context(db, source_id, workspace_id)
        related_ids: list[str] = []
        if context:
            related_ids = [node.id for node in context.related]
        source = graph_service.get_node(db, source_id, workspace_id)
        query = source.label if source else source_id
        response = self.search(db, query, SearchFilters(workspace_id=workspace_id), search_type='discovery', limit=30, record_history=False)
        related = [item for item in response.results if item.document_id != source_id][:15]
        forgotten = sorted(related, key=lambda item: item.metadata.get('updated_at', ''))[:5]
        missing_links = [node_id for node_id in related_ids if node_id not in {item.document_id for item in related}]
        recommendations = self._collection_recommendations(related)
        return DiscoveryResponse(source_id=source_id, related_results=related, related_node_ids=related_ids, forgotten_items=forgotten, missing_links=missing_links, recommended_collections=recommendations)

    def _collection_recommendations(self, results: list[SearchResult]) -> list[str]:
        groups: defaultdict[str, int] = defaultdict(int)
        for result in results:
            groups[result.source_type] += 1
        return [f'Related {source_type.replace("_", " ")} ({count})' for source_type, count in sorted(groups.items(), key=lambda item: item[1], reverse=True) if count >= 2][:5]

    def generate_study(self, db: Session, source_id: str, workspace_id: str, source_title: str, source_text: str, resource_type: str, force_refresh: bool = False) -> StudyResourceRead:
        source_hash = _content_hash(source_title, source_text)
        if not force_refresh:
            cached = db.scalar(select(StudyResourceModel).where(StudyResourceModel.workspace_id == workspace_id, StudyResourceModel.source_id == source_id, StudyResourceModel.resource_type == resource_type, StudyResourceModel.source_hash == source_hash))
            if cached:
                return self._study_read(cached, cached=True)
        sentences = [normalize_text(item) for item in re.split(r'(?<=[.!?])\s+', source_text) if normalize_text(item)]
        words = re.findall(r'[A-Za-z][A-Za-z0-9_-]{2,}', source_text.casefold())
        stopwords = {'the', 'and', 'for', 'with', 'from', 'that', 'this', 'are', 'was', 'into', 'their', 'have', 'will', 'about'}
        concepts = [item for item, _ in Counter(word for word in words if word not in stopwords).most_common(12)]
        definitions = re.findall(r'([A-Z][A-Za-z0-9 _-]{2,40})\s+(?:is|means|refers to)\s+([^.!?]{10,180})', source_text)
        formulas = [line.strip() for line in source_text.splitlines() if '=' in line and len(line.strip()) < 220][:12]
        dates = re.findall(r'\b(?:19|20)\d{2}\b|\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b', source_text)
        headings = [normalize_text(line.lstrip('#').strip()) for line in source_text.splitlines() if line.strip().startswith('#')]
        content: dict[str, Any] = {
            'summary': ' '.join(sentences[:3]),
            'detailed_summary': ' '.join(sentences[:12]),
            'key_concepts': concepts,
            'definitions': [{'term': term, 'definition': definition.strip()} for term, definition in definitions[:20]],
            'formulas': formulas,
            'important_dates': dates[:20],
            'chapter_overview': headings[:20],
            'learning_objectives': [f'Explain {concept}' for concept in concepts[:6]],
            'revision_notes': [sentence for sentence in sentences[:15]],
            'cheat_sheet': concepts[:10],
            'important_questions': [f'How does {concept} work?' for concept in concepts[:8]],
            'source_hash': source_hash,
        }
        existing = db.scalar(select(StudyResourceModel).where(StudyResourceModel.workspace_id == workspace_id, StudyResourceModel.source_id == source_id, StudyResourceModel.resource_type == resource_type))
        if existing is None:
            existing = StudyResourceModel(id=str(uuid4()), workspace_id=workspace_id, source_id=source_id, resource_type=resource_type, title=source_title or 'Study resource')
            db.add(existing)
        existing.title = source_title or existing.title
        existing.content_json = _json(content, {})
        existing.source_hash = source_hash
        existing.updated_at = utcnow()
        db.commit()
        db.refresh(existing)
        return self._study_read(existing, cached=False)

    def _study_read(self, resource: StudyResourceModel, cached: bool) -> StudyResourceRead:
        return StudyResourceRead(id=resource.id, source_id=resource.source_id, workspace_id=resource.workspace_id, resource_type=resource.resource_type, title=resource.title, content=_loads(resource.content_json, {}), cached=cached, created_at=resource.created_at, updated_at=resource.updated_at)

    def smart_collections(self, db: Session, workspace_id: str = '') -> list[SmartCollectionModel]:
        self.hydrate_index(db, workspace_id)
        by_type: defaultdict[str, list[str]] = defaultdict(list)
        for document_id, document in list(index._documents.items()):
            if document.metadata.get('workspace_id', '') not in {'', workspace_id}:
                continue
            by_type[document.source_type].append(document_id)
        collections: list[SmartCollectionModel] = []
        for source_type, item_ids in by_type.items():
            if len(item_ids) < 2:
                continue
            name = f'Related {source_type.replace("_", " ").title()}'
            collection = db.scalar(select(SmartCollectionModel).where(SmartCollectionModel.workspace_id == workspace_id, SmartCollectionModel.name == name))
            if collection is None:
                collection = SmartCollectionModel(id=str(uuid4()), workspace_id=workspace_id, name=name, ai_recommended=True)
                db.add(collection)
            collection.description = f'Automatically grouped {len(item_ids)} {source_type.replace("_", " ")} items.'
            collection.rule_json = _json({'source_type': source_type}, {})
            collection.item_ids_json = _json(item_ids[:500], [])
            collection.updated_at = utcnow()
            collections.append(collection)
        db.commit()
        return collections

    def commands(self) -> list[CommandItem]:
        return [
            CommandItem(id='navigate.dashboard', title='Open Dashboard', subtitle='FocusFlow command center', category='Navigate', route='/', action='navigate', icon='dashboard'),
            CommandItem(id='navigate.tasks', title='Open Tasks', subtitle='Smart task management', category='Navigate', route='/tasks', action='navigate', keywords=['todo', 'work'], icon='checklist'),
            CommandItem(id='navigate.calendar', title='Open Calendar', subtitle='Time intelligence', category='Navigate', route='/calendar', action='navigate', icon='calendar'),
            CommandItem(id='navigate.notes', title='Open Notes', subtitle='Second Brain', category='Navigate', route='/notes', action='navigate', keywords=['knowledge'], icon='notes'),
            CommandItem(id='navigate.projects', title='Open Projects', subtitle='Workspaces and goals', category='Navigate', route='/organization', action='navigate', keywords=['goals', 'workspace'], icon='folder'),
            CommandItem(id='navigate.assets', title='Open Assets', subtitle='Knowledge storage', category='Navigate', route='/assets', action='navigate', keywords=['files', 'pdf'], icon='asset'),
            CommandItem(id='navigate.graph', title='Open Knowledge Explorer', subtitle='Relationships and backlinks', category='Navigate', route='/knowledge-graph', action='navigate', keywords=['graph', 'relationships'], icon='hub'),
            CommandItem(id='navigate.reminders', title='Open Reminder Center', subtitle='Notifications and follow-ups', category='Navigate', route='/reminders', action='navigate', keywords=['alerts'], icon='notifications'),
            CommandItem(id='create.task', title='Create Task', subtitle='Add a new task', category='Create', action='create_task', keywords=['todo'], icon='add_task'),
            CommandItem(id='create.note', title='Create Note', subtitle='Capture knowledge', category='Create', action='create_note', keywords=['write'], icon='note_add'),
            CommandItem(id='focus.start', title='Start Focus Session', subtitle='Begin a distraction-free block', category='Execute', action='start_focus', keywords=['timer', 'deep work'], icon='timer'),
            CommandItem(id='assistant.open', title='Open AI Assistant', subtitle='Ask FocusFlow for help', category='Execute', route='/assistant', action='navigate', keywords=['chat', 'ask'], icon='assistant'),
        ]

    def search_commands(self, query: str, limit: int = 30) -> list[CommandItem]:
        terms = _tokens(query)
        commands = self.commands()
        if not terms:
            return commands[:limit]
        scored: list[tuple[float, CommandItem]] = []
        for command in commands:
            text = _tokens(' '.join([command.title, command.subtitle, command.category, ' '.join(command.keywords)]))
            score = len(terms & text) / max(1, len(terms))
            if query.casefold() in command.title.casefold():
                score += 1
            if score > 0:
                scored.append((score, command))
        scored.sort(key=lambda item: (-item[0], item[1].title))
        return [item[1] for item in scored[:limit]]

    def execute_command(self, command_id: str, workspace_id: str = '', parameters: dict[str, Any] | None = None) -> CommandExecutionResult:
        command = next((item for item in self.commands() if item.id == command_id), None)
        if command is None:
            return CommandExecutionResult(command_id=command_id, success=False, message='Command not found.')
        if command.action == 'navigate':
            return CommandExecutionResult(command_id=command_id, success=True, message=f'Opening {command.title}.', route=command.route)
        if command.action == 'start_focus':
            return CommandExecutionResult(command_id=command_id, success=True, message='Focus session ready to start.', payload={'workspace_id': workspace_id})
        if command.action in {'create_task', 'create_note'}:
            return CommandExecutionResult(command_id=command_id, success=True, message=f'{command.title} action ready.', payload={'workspace_id': workspace_id, 'parameters': parameters or {}})
        return CommandExecutionResult(command_id=command_id, success=True, message=f'{command.title} executed.')

    def knowledge_path(self, db: Session, query: str, workspace_id: str = '', max_steps: int = 8) -> KnowledgePathResponse:
        intent = self.interpret(query, SearchFilters(workspace_id=workspace_id))
        self.hydrate_index(db, workspace_id)
        hits = [hit for hit in index.search(intent.normalized_query, limit=20) if self._matches_filters(hit, intent.filters)]
        steps: list[dict[str, Any]] = []
        for hit in hits[:max_steps]:
            steps.append({'id': hit.document_id, 'title': hit.title, 'source_type': hit.source_type, 'snippet': hit.snippet})
        return KnowledgePathResponse(title=f'Learning path: {query}', steps=steps, explanation='A deterministic path ordered by query relevance and existing indexed context. Module 16 can reuse these steps without reprocessing sources.')


service = SearchService()
