from __future__ import annotations

import json
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.search.models import SavedSearchModel, SmartCollectionModel
from app.search.schemas import CommandExecuteRequest, CommandExecutionResult, CommandItem, CommandSearchRequest, DiscoveryResponse, KnowledgePathRequest, KnowledgePathResponse, SavedSearchCreate, SavedSearchRead, SearchHistoryRead, SearchIntent, SearchRequest, SearchResponse, SmartCollectionRead, StudyRequest, StudyResourceRead
from app.search.service import service

router = APIRouter(prefix='/search', tags=['global search'])


def _saved_read(item: SavedSearchModel) -> SavedSearchRead:
    return SavedSearchRead(id=item.id, workspace_id=item.workspace_id, name=item.name, query=item.query, filters=json.loads(item.filters_json or '{}'), favorite=item.favorite, created_at=item.created_at, updated_at=item.updated_at)


def _collection_read(item: SmartCollectionModel) -> SmartCollectionRead:
    return SmartCollectionRead(id=item.id, workspace_id=item.workspace_id, name=item.name, description=item.description, rule=json.loads(item.rule_json or '{}'), item_ids=json.loads(item.item_ids_json or '[]'), ai_recommended=item.ai_recommended, created_at=item.created_at, updated_at=item.updated_at)


@router.post('/query', response_model=SearchResponse)
def query_search(payload: SearchRequest, db: Session = Depends(get_db)) -> SearchResponse:
    return service.search(db, payload.query, payload.filters, payload.search_type, payload.limit)


@router.get('/query', response_model=SearchResponse)
def query_search_get(q: str = Query(min_length=1), workspace_id: str = '', search_type: str = 'keyword', limit: int = Query(default=50, ge=1, le=200), db: Session = Depends(get_db)) -> SearchResponse:
    from app.search.schemas import SearchFilters
    return service.search(db, q, SearchFilters(workspace_id=workspace_id), search_type, limit)


@router.get('/intent', response_model=SearchIntent)
def interpret_search(q: str = Query(min_length=1), workspace_id: str = '') -> SearchIntent:
    from app.search.schemas import SearchFilters
    return service.interpret(q, SearchFilters(workspace_id=workspace_id))


@router.get('/history', response_model=list[SearchHistoryRead])
def search_history(workspace_id: str = '', limit: int = Query(default=20, ge=1, le=100), db: Session = Depends(get_db)) -> list[SearchHistoryRead]:
    return [SearchHistoryRead.model_validate(item) for item in service.history(db, workspace_id, limit)]


@router.get('/saved', response_model=list[SavedSearchRead])
def saved_searches(workspace_id: str = '', db: Session = Depends(get_db)) -> list[SavedSearchRead]:
    return [_saved_read(item) for item in service.saved_searches(db, workspace_id)]


@router.post('/saved', response_model=SavedSearchRead, status_code=status.HTTP_201_CREATED)
def save_search(payload: SavedSearchCreate, db: Session = Depends(get_db)) -> SavedSearchRead:
    existing = db.scalar(select(SavedSearchModel).where(SavedSearchModel.workspace_id == payload.workspace_id, SavedSearchModel.name == payload.name))
    if existing is None:
        existing = SavedSearchModel(id=str(uuid4()), workspace_id=payload.workspace_id, name=payload.name, query=payload.query)
        db.add(existing)
    existing.query = payload.query
    existing.filters_json = payload.filters.model_dump_json()
    existing.favorite = payload.favorite
    db.commit()
    db.refresh(existing)
    return _saved_read(existing)


@router.delete('/saved/{saved_id}')
def delete_saved_search(saved_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> dict[str, bool]:
    statement = select(SavedSearchModel).where(SavedSearchModel.id == saved_id)
    if workspace_id:
        statement = statement.where(SavedSearchModel.workspace_id == workspace_id)
    saved = db.scalar(statement)
    if saved is None:
        raise HTTPException(status_code=404, detail='Saved search not found')
    db.delete(saved)
    db.commit()
    return {'deleted': True}


@router.get('/commands', response_model=list[CommandItem])
def commands(q: str = '', limit: int = Query(default=30, ge=1, le=100)) -> list[CommandItem]:
    return service.search_commands(q, limit)


@router.post('/commands/search', response_model=list[CommandItem])
def command_search(payload: CommandSearchRequest) -> list[CommandItem]:
    return service.search_commands(payload.query, payload.limit)


@router.post('/commands/execute', response_model=CommandExecutionResult)
def execute_command(payload: CommandExecuteRequest) -> CommandExecutionResult:
    return service.execute_command(payload.command_id, payload.workspace_id, payload.parameters)


@router.get('/discovery/{source_id}', response_model=DiscoveryResponse)
def discovery(source_id: str, workspace_id: str = '', db: Session = Depends(get_db)) -> DiscoveryResponse:
    return service.discovery(db, source_id, workspace_id)


@router.post('/study', response_model=StudyResourceRead)
def study(payload: StudyRequest, db: Session = Depends(get_db)) -> StudyResourceRead:
    return service.generate_study(db, payload.source_id, payload.workspace_id, payload.source_title, payload.source_text, payload.resource_type, payload.force_refresh)


@router.get('/collections', response_model=list[SmartCollectionRead])
def smart_collections(workspace_id: str = '', db: Session = Depends(get_db)) -> list[SmartCollectionRead]:
    return [_collection_read(item) for item in service.smart_collections(db, workspace_id)]


@router.post('/knowledge-path', response_model=KnowledgePathResponse)
def knowledge_path(payload: KnowledgePathRequest, db: Session = Depends(get_db)) -> KnowledgePathResponse:
    return service.knowledge_path(db, payload.query, payload.workspace_id, payload.max_steps)
