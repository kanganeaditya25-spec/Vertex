from datetime import UTC, datetime
import json
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.assistant.engine import assistant_engine
from app.assistant.models import AssistantActionAuditModel, AssistantConversationModel, AssistantMemoryModel, AssistantMessageModel, AssistantSyncQueueModel
from app.assistant.schemas import AssistantAction, AssistantSource, ChatRequest, ChatResponse, ConversationMessageRead, ConversationRead, DailyBriefResponse, MemoryCreate, MemoryRead, WorkspaceSearchRequest, WorkspaceSearchResponse
from app.db.session import get_db

router = APIRouter(prefix="/assistant", tags=["assistant"])


def _now() -> datetime:
    return datetime.now(UTC)


def _sources(value: str) -> list[AssistantSource]:
    try:
        return [AssistantSource.model_validate(item) for item in json.loads(value or "[]")]
    except (TypeError, ValueError):
        return []


def _actions(value: str) -> list[AssistantAction]:
    try:
        return [AssistantAction.model_validate(item) for item in json.loads(value or "[]")]
    except (TypeError, ValueError):
        return []


def _message_response(conversation_id: str, message: AssistantMessageModel) -> ChatResponse:
    return ChatResponse(conversation_id=conversation_id, message_id=message.id, content=message.content, mode=message.mode, reasoning=message.reasoning, sources=_sources(message.sources_json), actions=_actions(message.actions_json), created_at=message.created_at)


def _get_conversation(db: Session, conversation_id: str) -> AssistantConversationModel:
    statement = select(AssistantConversationModel).options(selectinload(AssistantConversationModel.messages)).where(AssistantConversationModel.id == conversation_id, AssistantConversationModel.archived.is_(False))
    conversation = db.scalar(statement)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Assistant conversation not found")
    return conversation


@router.post("/chat", response_model=ChatResponse)
def chat(payload: ChatRequest, db: Session = Depends(get_db)) -> ChatResponse:
    conversation = _get_conversation(db, payload.conversation_id) if payload.conversation_id else AssistantConversationModel(id=str(uuid4()), title=payload.message[:80], scope="workspace")
    if conversation.id not in {item[0] for item in db.execute(select(AssistantConversationModel.id)).all()}:
        db.add(conversation)
        db.flush()
    user_message = AssistantMessageModel(id=str(uuid4()), conversation_id=conversation.id, role="user", content=payload.message, mode="local_rule")
    db.add(user_message)
    result = assistant_engine.respond(db, payload.message, payload.include_sources)
    assistant_message = AssistantMessageModel(id=str(uuid4()), conversation_id=conversation.id, role="assistant", content=result.content, mode=result.mode, reasoning=result.reasoning, sources_json=json.dumps([source.model_dump(mode="json") for source in result.sources]), actions_json=json.dumps([action.model_dump(mode="json") for action in result.actions]))
    db.add(assistant_message)
    conversation.updated_at = _now()
    for action in result.actions:
        db.add(AssistantActionAuditModel(id=str(uuid4()), conversation_id=conversation.id, action_type=action.action_type, request_text=payload.message, result_text=action.label, reasoning=result.reasoning, status=action.status))
    db.commit()
    return _message_response(conversation.id, assistant_message)


@router.get("/conversations", response_model=list[ConversationRead])
def list_conversations(limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db)) -> list[dict]:
    conversations = db.scalars(select(AssistantConversationModel).options(selectinload(AssistantConversationModel.messages)).where(AssistantConversationModel.archived.is_(False)).order_by(AssistantConversationModel.pinned.desc(), AssistantConversationModel.updated_at.desc()).limit(limit)).unique().all()
    return [_serialize_conversation(conversation) for conversation in conversations]


@router.get("/conversations/{conversation_id}", response_model=ConversationRead)
def get_conversation(conversation_id: str, db: Session = Depends(get_db)) -> dict:
    return _serialize_conversation(_get_conversation(db, conversation_id))


@router.post("/memories", response_model=MemoryRead, status_code=status.HTTP_201_CREATED)
def create_memory(payload: MemoryCreate, db: Session = Depends(get_db)) -> AssistantMemoryModel:
    memory = AssistantMemoryModel(id=str(uuid4()), memory_type=payload.memory_type, scope_id=payload.scope_id, content=payload.content.strip(), source=payload.source, confidence=payload.confidence, importance=payload.importance, pinned=payload.pinned)
    db.add(memory)
    db.add(AssistantSyncQueueModel(id=str(uuid4()), entity_type="memory", entity_id=memory.id, operation="create", payload=json.dumps(payload.model_dump()), version=memory.version))
    db.commit()
    db.refresh(memory)
    return memory


@router.get("/memories", response_model=list[MemoryRead])
def list_memories(search: str | None = None, pinned_only: bool = False, limit: int = Query(default=100, ge=1, le=500), db: Session = Depends(get_db)) -> list[AssistantMemoryModel]:
    statement = select(AssistantMemoryModel).where(AssistantMemoryModel.archived.is_(False))
    if search:
        statement = statement.where(AssistantMemoryModel.content.ilike(f"%{search.strip()}%"))
    if pinned_only:
        statement = statement.where(AssistantMemoryModel.pinned.is_(True))
    return list(db.scalars(statement.order_by(AssistantMemoryModel.pinned.desc(), AssistantMemoryModel.importance.desc(), AssistantMemoryModel.updated_at.desc()).limit(limit)).all())


@router.patch("/memories/{memory_id}", response_model=MemoryRead)
def update_memory(memory_id: str, pinned: bool | None = None, archived: bool | None = None, db: Session = Depends(get_db)) -> AssistantMemoryModel:
    memory = db.scalar(select(AssistantMemoryModel).where(AssistantMemoryModel.id == memory_id))
    if memory is None:
        raise HTTPException(status_code=404, detail="Assistant memory not found")
    if pinned is not None:
        memory.pinned = pinned
    if archived is not None:
        memory.archived = archived
    memory.version += 1
    db.add(AssistantSyncQueueModel(id=str(uuid4()), entity_type="memory", entity_id=memory.id, operation="update", payload=json.dumps({"pinned": memory.pinned, "archived": memory.archived}), version=memory.version))
    db.commit()
    db.refresh(memory)
    return memory


@router.post("/search", response_model=WorkspaceSearchResponse)
def workspace_search(payload: WorkspaceSearchRequest, db: Session = Depends(get_db)) -> WorkspaceSearchResponse:
    result = assistant_engine.search(db, payload.query)
    return WorkspaceSearchResponse(query=payload.query, mode=result.mode, results=result.sources[: payload.limit], reasoning=result.reasoning)


@router.get("/brief/morning", response_model=DailyBriefResponse)
def morning_brief(db: Session = Depends(get_db)) -> DailyBriefResponse:
    plan = assistant_engine.week_plan(db)
    return DailyBriefResponse(brief_type="morning", title="Morning brief", content=f"Start with your most important work.\n\n{plan.content}", reasoning=plan.reasoning, sources=plan.sources, actions=plan.actions)


@router.get("/brief/evening", response_model=DailyBriefResponse)
def evening_brief(db: Session = Depends(get_db)) -> DailyBriefResponse:
    overdue = assistant_engine.overdue_tasks(db)
    return DailyBriefResponse(brief_type="evening", title="Evening review", content=f"Review what is complete, then protect tomorrow's first focus block.\n\n{overdue.content}", reasoning="The evening review uses local overdue-task state as a transparent signal for tomorrow planning.", sources=overdue.sources, actions=overdue.actions)


def _serialize_conversation(conversation: AssistantConversationModel) -> dict:
    return {"id": conversation.id, "title": conversation.title, "scope": conversation.scope, "pinned": conversation.pinned, "archived": conversation.archived, "updated_at": conversation.updated_at, "messages": [{"id": message.id, "role": message.role, "content": message.content, "mode": message.mode, "reasoning": message.reasoning, "sources": [source.model_dump(mode="json") for source in _sources(message.sources_json)], "actions": [action.model_dump(mode="json") for action in _actions(message.actions_json)], "created_at": message.created_at} for message in conversation.messages]}
