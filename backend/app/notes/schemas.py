from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator


class BlockInput(BaseModel):
    block_type: str = Field(default="paragraph", max_length=32)
    content: str = Field(default="", max_length=100_000)
    position: int = Field(default=0, ge=0)
    checked: bool = False
    collapsed: bool = False
    metadata: dict[str, object] = Field(default_factory=dict)


class BlockRead(BlockInput):
    model_config = ConfigDict(from_attributes=True)

    id: str
    note_id: str
    created_at: datetime
    updated_at: datetime


class NoteCreate(BaseModel):
    title: str = Field(min_length=1, max_length=240)
    note_type: str = "rich"
    summary: str = Field(default="", max_length=20_000)
    blocks: list[BlockInput] = Field(default_factory=list, max_length=1000)
    folder_id: Optional[str] = None
    workspace: Optional[str] = Field(default=None, max_length=120)
    project_id: Optional[str] = None
    tags: list[str] = Field(default_factory=list, max_length=50)
    color: Optional[str] = Field(default=None, max_length=32)
    icon: Optional[str] = Field(default=None, max_length=64)
    pinned: bool = False
    favorite: bool = False
    private: bool = False
    importance_score: float = Field(default=50, ge=0, le=100)

    @model_validator(mode="after")
    def require_meaningful_content(self) -> "NoteCreate":
        if len(self.title.strip()) == 0:
            raise ValueError("title is required")
        if sum(len(block.content) for block in self.blocks) > 2_000_000:
            raise ValueError("note content exceeds the 2 MB limit")
        return self


class NoteUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=240)
    note_type: Optional[str] = None
    summary: Optional[str] = Field(default=None, max_length=20_000)
    blocks: Optional[list[BlockInput]] = Field(default=None, max_length=1000)
    folder_id: Optional[str] = None
    workspace: Optional[str] = Field(default=None, max_length=120)
    project_id: Optional[str] = None
    tags: Optional[list[str]] = Field(default=None, max_length=50)
    color: Optional[str] = Field(default=None, max_length=32)
    icon: Optional[str] = Field(default=None, max_length=64)
    pinned: Optional[bool] = None
    favorite: Optional[bool] = None
    importance_score: Optional[float] = Field(default=None, ge=0, le=100)
    change_summary: str = Field(default="Edited note", max_length=240)


class TagRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    color: Optional[str] = None


class NoteRead(BaseModel):
    id: str
    title: str
    note_type: str
    summary: str
    markdown_content: str
    folder_id: Optional[str]
    workspace: Optional[str]
    project_id: Optional[str]
    color: Optional[str]
    icon: Optional[str]
    pinned: bool
    favorite: bool
    archived: bool
    deleted: bool
    word_count: int
    reading_time_minutes: int
    language: str
    knowledge_score: float
    importance_score: float
    version: int
    sync_status: str
    created_at: datetime
    updated_at: datetime
    archived_at: Optional[datetime]
    deleted_at: Optional[datetime]
    tags: list[TagRead] = Field(default_factory=list)
    blocks: list[BlockRead] = Field(default_factory=list)
    outgoing_note_ids: list[str] = Field(default_factory=list)
    incoming_note_ids: list[str] = Field(default_factory=list)


class NoteLinkCreate(BaseModel):
    source_note_id: str
    target_note_id: str
    link_type: str = Field(default="related", max_length=24)


class NoteSearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=500)
    tags: list[str] = Field(default_factory=list, max_length=20)
    favorite_only: bool = False
    include_archived: bool = False
    limit: int = Field(default=50, ge=1, le=500)


class NoteVersionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    note_id: str
    version: int
    title: str
    blocks_json: str
    change_summary: str
    author: Optional[str]
    created_at: datetime


class NoteHistoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    note_id: str
    action: str
    details: str
    created_at: datetime


class NoteStatistics(BaseModel):
    total_notes: int
    archived_notes: int
    favorite_notes: int
    linked_notes: int
    total_words: int
    top_tags: list[dict[str, object]]
