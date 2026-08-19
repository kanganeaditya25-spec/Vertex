from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class AssetBase(BaseModel):
    name: str = Field(min_length=1, max_length=240)
    asset_type: str = Field(default="file", max_length=40)
    source_kind: str = Field(default="file", max_length=24)
    extension: str = Field(default="", max_length=24)
    mime_type: str = Field(default="application/octet-stream", max_length=160)
    size_bytes: int = Field(default=0, ge=0)
    file_hash: str = Field(default="", max_length=128)
    storage_key: str = Field(default="", max_length=500)
    source_url: str = Field(default="", max_length=2000)
    preview_text: str = ""
    ocr_text: str = ""
    thumbnail_key: str = Field(default="", max_length=500)
    workspace_id: str = Field(default="", max_length=64)
    project_id: str = Field(default="", max_length=64)
    folder_id: str = Field(default="root", max_length=64)
    category: str = Field(default="uncategorized", max_length=80)
    tags: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)
    linked_task_ids: list[str] = Field(default_factory=list)
    linked_note_ids: list[str] = Field(default_factory=list)
    linked_event_ids: list[str] = Field(default_factory=list)
    linked_goal_ids: list[str] = Field(default_factory=list)
    linked_reminder_ids: list[str] = Field(default_factory=list)
    linked_assistant_thread_ids: list[str] = Field(default_factory=list)
    favorite: bool = False
    pinned: bool = False
    archived: bool = False
    trashed: bool = False
    hidden: bool = False
    encrypted: bool = False
    locked: bool = False
    reading_progress: float = Field(default=0.0, ge=0.0, le=1.0)


class AssetCreate(AssetBase):
    id: str | None = Field(default=None, max_length=64)


class AssetUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=240)
    folder_id: str | None = Field(default=None, max_length=64)
    workspace_id: str | None = Field(default=None, max_length=64)
    project_id: str | None = Field(default=None, max_length=64)
    category: str | None = Field(default=None, max_length=80)
    tags: list[str] | None = None
    metadata: dict[str, Any] | None = None
    source_url: str | None = Field(default=None, max_length=2000)
    preview_text: str | None = None
    ocr_text: str | None = None
    favorite: bool | None = None
    pinned: bool | None = None
    archived: bool | None = None
    trashed: bool | None = None
    hidden: bool | None = None
    encrypted: bool | None = None
    locked: bool | None = None
    reading_progress: float | None = Field(default=None, ge=0.0, le=1.0)
    linked_task_ids: list[str] | None = None
    linked_note_ids: list[str] | None = None
    linked_event_ids: list[str] | None = None
    linked_goal_ids: list[str] | None = None
    linked_reminder_ids: list[str] | None = None
    linked_assistant_thread_ids: list[str] | None = None


class AssetRead(AssetBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    version: int
    created_at: datetime
    modified_at: datetime


class AssetSearchResult(AssetRead):
    match_reason: str = "metadata"


class AssetFolderCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    parent_id: str = Field(default="root", max_length=64)
    workspace_id: str = Field(default="", max_length=64)
    project_id: str = Field(default="", max_length=64)
    smart_query: str = Field(default="", max_length=500)


class AssetFolderRead(AssetFolderCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    archived: bool
    created_at: datetime
    modified_at: datetime


class AssetCollectionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = ""
    asset_ids: list[str] = Field(default_factory=list)
    password_protected: bool = False


class AssetCollectionRead(AssetCollectionCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    modified_at: datetime


class AssetVersionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    asset_id: str
    version: int
    action: str
    name: str
    file_hash: str
    size_bytes: int
    storage_key: str
    metadata_json: dict[str, Any]
    created_at: datetime


class AssetStats(BaseModel):
    total_storage_bytes: int
    file_count: int
    archived_count: int
    trashed_count: int
    favorite_count: int
    largest_files: list[AssetRead]
    category_counts: dict[str, int]
    recent_uploads: list[AssetRead]
    duplicate_groups: list[list[str]]


class BulkAssetAction(BaseModel):
    asset_ids: list[str] = Field(min_length=1)
    action: str = Field(pattern="^(move|delete|restore|archive|favorite|pin|tag|export)$")
    folder_id: str | None = None
    tags: list[str] | None = None


class AssetLinkRequest(BaseModel):
    relation: str = Field(pattern="^(task|note|event|goal|reminder|assistant)$")
    related_id: str = Field(min_length=1, max_length=64)
    linked: bool = True


class AssetUrlCreate(BaseModel):
    name: str = Field(min_length=1, max_length=240)
    url: HttpUrl
    description: str = ""
    thumbnail_url: str = ""
    tags: list[str] = Field(default_factory=list)
    category: str = "url"


class OcrResult(BaseModel):
    asset: AssetRead
    text: str
    engine: str
    pages_processed: int = 1

class ArchiveExport(BaseModel):
    asset_ids: list[str]
    filename: str
    manifest: dict[str, Any]


class AssetExportRequest(BaseModel):
    asset_ids: list[str] = Field(min_length=1)
    filename: str = Field(default="asset-library-export.zip", max_length=160)
