from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.graph.schemas import DuplicateGroup, GraphContext, GraphInsight, GraphNodeRead, GraphNodeUpsert, GraphPathResponse, GraphSearchResponse, GraphStats, GraphSuggestionRead, RelationshipCreate, RelationshipRead
from app.graph.service import _node_read, _relationship_read, _suggestion_read, service

router = APIRouter(prefix='/graph', tags=['knowledge graph'])


@router.post('/nodes', response_model=GraphNodeRead, status_code=status.HTTP_201_CREATED)
def upsert_node(payload: GraphNodeUpsert, db: Session = Depends(get_db)) -> GraphNodeRead:
    node = service.upsert_node(db, entity_type=payload.entity_type, entity_id=payload.entity_id, workspace_id=payload.workspace_id, label=payload.label, content_text=payload.content_text, tags=payload.tags, metadata=payload.metadata, active=payload.active)
    db.commit()
    db.refresh(node)
    return _node_read(node)


@router.get('/nodes', response_model=list[GraphNodeRead])
def list_nodes(workspace_id: str = '', entity_type: str | None = None, q: str | None = None, limit: int = Query(default=100, ge=1, le=500), db: Session = Depends(get_db)) -> list[GraphNodeRead]:
    return [_node_read(node) for node in service.list_nodes(db, workspace_id, entity_type, q, limit)]


@router.get('/nodes/{node_id}', response_model=GraphNodeRead)
def get_node(node_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> GraphNodeRead:
    node = service.get_node(db, node_id, workspace_id)
    if node is None:
        raise HTTPException(status_code=404, detail='Graph node not found')
    return _node_read(node)


@router.delete('/nodes/{node_id}')
def delete_node(node_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> dict[str, bool]:
    deleted = service.delete_node(db, node_id, workspace_id)
    if not deleted:
        raise HTTPException(status_code=404, detail='Graph node not found')
    db.commit()
    return {'deleted': True}


@router.post('/relationships', response_model=RelationshipRead, status_code=status.HTTP_201_CREATED)
def create_relationship(payload: RelationshipCreate, db: Session = Depends(get_db)) -> RelationshipRead:
    try:
        relationship = service.ensure_relationship(db, workspace_id=payload.workspace_id, source_node_id=payload.source_node_id, target_node_id=payload.target_node_id, relationship_type=payload.relationship_type, weight=payload.weight, confidence=payload.confidence, explanation=payload.explanation, source=payload.source, metadata=payload.metadata)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    db.commit()
    db.refresh(relationship)
    return _relationship_read(relationship)


@router.get('/relationships', response_model=list[RelationshipRead])
def list_relationships(workspace_id: str = '', node_id: str | None = None, relationship_type: str | None = None, limit: int = Query(default=200, ge=1, le=1_000), db: Session = Depends(get_db)) -> list[RelationshipRead]:
    return [_relationship_read(item) for item in service.list_relationships(db, workspace_id, node_id, relationship_type, limit)]


@router.delete('/relationships/{relationship_id}')
def delete_relationship(relationship_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> dict[str, bool]:
    if not service.remove_relationship(db, relationship_id, workspace_id):
        raise HTTPException(status_code=404, detail='Graph relationship not found')
    db.commit()
    return {'deleted': True}


@router.get('/context/{node_id}', response_model=GraphContext)
def graph_context(node_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> GraphContext:
    context = service.context(db, node_id, workspace_id)
    if context is None:
        raise HTTPException(status_code=404, detail='Graph node not found')
    return context


@router.get('/search', response_model=GraphSearchResponse)
def graph_search(q: str = Query(min_length=1), workspace_id: str = '', limit: int = Query(default=50, ge=1, le=200), db: Session = Depends(get_db)) -> GraphSearchResponse:
    return service.search(db, q, workspace_id, limit)


@router.get('/path/{source_node_id}/{target_node_id}', response_model=GraphPathResponse)
def graph_path(source_node_id: str, target_node_id: str, workspace_id: str = '', max_depth: int = Query(default=8, ge=1, le=20), db: Session = Depends(get_db)) -> GraphPathResponse:
    return service.path(db, source_node_id, target_node_id, workspace_id, max_depth)


@router.get('/stats', response_model=GraphStats)
def graph_stats(workspace_id: str = '', db: Session = Depends(get_db)) -> GraphStats:
    return service.stats(db, workspace_id)


@router.get('/suggestions', response_model=list[GraphSuggestionRead])
def graph_suggestions(workspace_id: str = '', limit: int = Query(default=50, ge=1, le=100), db: Session = Depends(get_db)) -> list[GraphSuggestionRead]:
    suggestions = service.suggestions(db, workspace_id, limit)
    db.commit()
    return [_suggestion_read(item) for item in suggestions]


@router.post('/suggestions/{suggestion_id}/accept', response_model=RelationshipRead)
def accept_suggestion(suggestion_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> RelationshipRead:
    relationship = service.accept_suggestion(db, suggestion_id, workspace_id)
    if relationship is None:
        raise HTTPException(status_code=404, detail='Graph suggestion not found')
    db.commit()
    db.refresh(relationship)
    return _relationship_read(relationship)


@router.post('/suggestions/{suggestion_id}/dismiss')
def dismiss_suggestion(suggestion_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> dict[str, bool]:
    from sqlalchemy import select
    from app.graph.models import GraphSuggestionModel

    statement = select(GraphSuggestionModel).where(GraphSuggestionModel.id == suggestion_id)
    if workspace_id:
        statement = statement.where(GraphSuggestionModel.workspace_id == workspace_id)
    suggestion = db.scalar(statement)
    if suggestion is None:
        raise HTTPException(status_code=404, detail='Graph suggestion not found')
    suggestion.status = 'dismissed'
    db.commit()
    return {'dismissed': True}


@router.get('/insights', response_model=list[GraphInsight])
def graph_insights(workspace_id: str = '', db: Session = Depends(get_db)) -> list[GraphInsight]:
    return service.insights(db, workspace_id)


@router.get('/duplicates', response_model=list[DuplicateGroup])
def graph_duplicates(workspace_id: str = '', limit: int = Query(default=50, ge=1, le=100), db: Session = Depends(get_db)) -> list[DuplicateGroup]:
    return service.duplicates(db, workspace_id, limit)
