from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.utils.common import utcnow
from app.db.session import Base


class SearchHistoryModel(Base):
    __tablename__ = 'search_history_v1'
    __table_args__ = (Index('ix_search_history_scope_time', 'workspace_id', 'created_at'),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    query: Mapped[str] = mapped_column(String(500), nullable=False)
    search_type: Mapped[str] = mapped_column(String(32), default='keyword', nullable=False)
    result_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class SavedSearchModel(Base):
    __tablename__ = 'saved_searches_v1'
    __table_args__ = (UniqueConstraint('workspace_id', 'name', name='uq_saved_search_scope_name'),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    query: Mapped[str] = mapped_column(String(500), nullable=False)
    filters_json: Mapped[str] = mapped_column(Text, default='{}', nullable=False)
    favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)


class SmartCollectionModel(Base):
    __tablename__ = 'smart_collections_v1'
    __table_args__ = (Index('ix_smart_collections_scope', 'workspace_id'),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str] = mapped_column(Text, default='', nullable=False)
    rule_json: Mapped[str] = mapped_column(Text, default='{}', nullable=False)
    item_ids_json: Mapped[str] = mapped_column(Text, default='[]', nullable=False)
    ai_recommended: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)


class StudyResourceModel(Base):
    __tablename__ = 'study_resources_v1'
    __table_args__ = (UniqueConstraint('workspace_id', 'source_id', 'resource_type', name='uq_study_resource_source_type'),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    source_id: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    resource_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    content_json: Mapped[str] = mapped_column(Text, default='{}', nullable=False)
    source_hash: Mapped[str] = mapped_column(String(64), default='', nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)
