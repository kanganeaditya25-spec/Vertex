from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AssistantSource(BaseModel):
    source_type: str
    source_id: str
    title: str
    excerpt: str = ""
    route: Optional[str] = None


class AssistantAction(BaseModel):
    action_type: str
    label: str
    status: str = "preview"
    payload: dict[str, object] = Field(default_factory=dict)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=10_000)
    conversation_id: Optional[str] = None
    include_sources: bool = True


class ChatResponse(BaseModel):
    conversation_id: str
    message_id: str
    content: str
    mode: str
    reasoning: str
    sources: list[AssistantSource] = Field(default_factory=list)
    actions: list[AssistantAction] = Field(default_factory=list)
    created_at: datetime


class ConversationMessageRead(BaseModel):
    id: str
    role: str
    content: str
    mode: str
    reasoning: str
    sources: list[AssistantSource] = Field(default_factory=list)
    actions: list[AssistantAction] = Field(default_factory=list)
    created_at: datetime


class ConversationRead(BaseModel):
    id: str
    title: str
    scope: str
    pinned: bool
    archived: bool
    updated_at: datetime
    messages: list[ConversationMessageRead] = Field(default_factory=list)


class MemoryCreate(BaseModel):
    content: str = Field(min_length=1, max_length=5000)
    memory_type: str = Field(default="workspace", max_length=32)
    scope_id: Optional[str] = None
    source: str = Field(default="user", max_length=32)
    confidence: float = Field(default=0.8, ge=0, le=1)
    importance: float = Field(default=50, ge=0, le=100)
    pinned: bool = False


class MemoryRead(BaseModel):
    id: str
    memory_type: str
    scope_id: Optional[str]
    content: str
    source: str
    confidence: float
    importance: float
    pinned: bool
    archived: bool
    version: int
    sync_status: str
    created_at: datetime
    updated_at: datetime


class WorkspaceSearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=500)
    limit: int = Field(default=30, ge=1, le=200)


class WorkspaceSearchResponse(BaseModel):
    query: str
    mode: str
    results: list[AssistantSource] = Field(default_factory=list)
    reasoning: str


class DailyBriefResponse(BaseModel):
    brief_type: str
    title: str
    content: str
    reasoning: str
    sources: list[AssistantSource] = Field(default_factory=list)
    actions: list[AssistantAction] = Field(default_factory=list)
