from datetime import UTC, datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


def utc_now() -> datetime:
    return datetime.now(UTC)


class NoteModel(Base):
    __tablename__ = "notes_v5"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    note_type: Mapped[str] = mapped_column(String(32), default="rich", index=True)
    summary: Mapped[str] = mapped_column(Text, default="", nullable=False)
    plain_text: Mapped[str] = mapped_column(Text, default="", nullable=False)
    markdown_content: Mapped[str] = mapped_column(Text, default="", nullable=False)
    folder_id: Mapped[Optional[str]] = mapped_column(ForeignKey("note_folders_v5.id"), nullable=True, index=True)
    workspace: Mapped[Optional[str]] = mapped_column(String(120), nullable=True, index=True)
    project_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True, index=True)
    author: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    color: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    icon: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    pinned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    favorite: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    deleted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    ai_generated: Mapped[bool] = mapped_column(Boolean, default=False)
    encrypted: Mapped[bool] = mapped_column(Boolean, default=False)
    word_count: Mapped[int] = mapped_column(Integer, default=0)
    reading_time_minutes: Mapped[int] = mapped_column(Integer, default=0)
    language: Mapped[str] = mapped_column(String(16), default="en")
    knowledge_score: Mapped[float] = mapped_column(default=0.0)
    importance_score: Mapped[float] = mapped_column(default=50.0)
    semantic_embedding_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    sync_status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)
    archived_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    folder: Mapped[Optional["FolderModel"]] = relationship(back_populates="notes")
    blocks: Mapped[list["NoteBlockModel"]] = relationship(cascade="all, delete-orphan", order_by="NoteBlockModel.position")
    tags: Mapped[list["NoteTagModel"]] = relationship(cascade="all, delete-orphan")
    outgoing_links: Mapped[list["NoteLinkModel"]] = relationship(foreign_keys="NoteLinkModel.source_note_id", cascade="all, delete-orphan")
    incoming_links: Mapped[list["NoteLinkModel"]] = relationship(foreign_keys="NoteLinkModel.target_note_id", cascade="all, delete-orphan")
    versions: Mapped[list["NoteVersionModel"]] = relationship(cascade="all, delete-orphan", order_by="NoteVersionModel.version")
    history: Mapped[list["NoteHistoryModel"]] = relationship(cascade="all, delete-orphan", order_by="NoteHistoryModel.created_at")


class NoteBlockModel(Base):
    __tablename__ = "note_blocks_v5"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    note_id: Mapped[str] = mapped_column(ForeignKey("notes_v5.id", ondelete="CASCADE"), index=True)
    block_type: Mapped[str] = mapped_column(String(32), default="paragraph", index=True)
    content: Mapped[str] = mapped_column(Text, default="", nullable=False)
    position: Mapped[int] = mapped_column(Integer, default=0)
    checked: Mapped[bool] = mapped_column(Boolean, default=False)
    collapsed: Mapped[bool] = mapped_column(Boolean, default=False)
    metadata_json: Mapped[str] = mapped_column(Text, default="{}", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class FolderModel(Base):
    __tablename__ = "note_folders_v5"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    parent_id: Mapped[Optional[str]] = mapped_column(ForeignKey("note_folders_v5.id"), nullable=True, index=True)
    color: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    icon: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    archived: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)

    parent: Mapped[Optional["FolderModel"]] = relationship(remote_side=[id], back_populates="children")
    children: Mapped[list["FolderModel"]] = relationship(back_populates="parent")
    notes: Mapped[list[NoteModel]] = relationship(back_populates="folder")


class NoteTagModel(Base):
    __tablename__ = "note_tags_v5"
    __table_args__ = (UniqueConstraint("note_id", "name", name="uq_note_tag_v5"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    note_id: Mapped[str] = mapped_column(ForeignKey("notes_v5.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    color: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class NoteLinkModel(Base):
    __tablename__ = "note_links_v5"
    __table_args__ = (UniqueConstraint("source_note_id", "target_note_id", "link_type", name="uq_note_link_v5"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source_note_id: Mapped[str] = mapped_column(ForeignKey("notes_v5.id", ondelete="CASCADE"), index=True)
    target_note_id: Mapped[str] = mapped_column(ForeignKey("notes_v5.id", ondelete="CASCADE"), index=True)
    link_type: Mapped[str] = mapped_column(String(24), default="related")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class NoteVersionModel(Base):
    __tablename__ = "note_versions_v5"
    __table_args__ = (UniqueConstraint("note_id", "version", name="uq_note_version_v5"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    note_id: Mapped[str] = mapped_column(ForeignKey("notes_v5.id", ondelete="CASCADE"), index=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    blocks_json: Mapped[str] = mapped_column(Text, nullable=False)
    change_summary: Mapped[str] = mapped_column(String(240), default="")
    author: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class NoteHistoryModel(Base):
    __tablename__ = "note_history_v5"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    note_id: Mapped[str] = mapped_column(ForeignKey("notes_v5.id", ondelete="CASCADE"), index=True)
    action: Mapped[str] = mapped_column(String(48), nullable=False)
    details: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class NoteSyncQueueModel(Base):
    __tablename__ = "note_sync_queue_v5"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    note_id: Mapped[str] = mapped_column(String(36), index=True)
    operation: Mapped[str] = mapped_column(String(24), nullable=False)
    payload: Mapped[str] = mapped_column(Text, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
