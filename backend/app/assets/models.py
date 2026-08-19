from datetime import UTC, datetime
from typing import Any

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def utc_now() -> datetime:
    return datetime.now(UTC)


class AssetModel(Base):
    __tablename__ = "assets_v1"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    asset_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    source_kind: Mapped[str] = mapped_column(String(24), default="file", nullable=False)
    extension: Mapped[str] = mapped_column(String(24), default="", nullable=False)
    mime_type: Mapped[str] = mapped_column(String(160), default="application/octet-stream", nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    file_hash: Mapped[str] = mapped_column(String(128), default="", nullable=False, index=True)
    storage_key: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    source_url: Mapped[str] = mapped_column(String(2000), default="", nullable=False)
    preview_text: Mapped[str] = mapped_column(Text, default="", nullable=False)
    ocr_text: Mapped[str] = mapped_column(Text, default="", nullable=False)
    thumbnail_key: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    workspace_id: Mapped[str] = mapped_column(String(64), default="", nullable=False, index=True)
    project_id: Mapped[str] = mapped_column(String(64), default="", nullable=False, index=True)
    folder_id: Mapped[str] = mapped_column(String(64), default="root", nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(80), default="uncategorized", nullable=False, index=True)
    tags: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    linked_task_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_note_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_event_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_goal_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_reminder_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_assistant_thread_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    favorite: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    pinned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    trashed: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    encrypted: Mapped[bool] = mapped_column(Boolean, default=False)
    locked: Mapped[bool] = mapped_column(Boolean, default=False)
    reading_progress: Mapped[float] = mapped_column(default=0.0)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)
    modified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class AssetFolderModel(Base):
    __tablename__ = "asset_folders_v1"
    __table_args__ = (UniqueConstraint("parent_id", "name", name="uq_asset_folder_parent_name"),)

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    parent_id: Mapped[str] = mapped_column(String(64), default="root", nullable=False, index=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default="", nullable=False, index=True)
    project_id: Mapped[str] = mapped_column(String(64), default="", nullable=False, index=True)
    smart_query: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    modified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class AssetCollectionModel(Base):
    __tablename__ = "asset_collections_v1"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    asset_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    password_protected: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    modified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class AssetVersionModel(Base):
    __tablename__ = "asset_versions_v1"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    asset_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    action: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str] = mapped_column(String(240), nullable=False)
    file_hash: Mapped[str] = mapped_column(String(128), default="", nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    storage_key: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class AssetSyncQueueModel(Base):
    __tablename__ = "asset_sync_queue_v1"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    asset_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    operation: Mapped[str] = mapped_column(String(32), nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
