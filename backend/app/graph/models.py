from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import Boolean, DateTime, Float, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.core.utils.common import utcnow

utc_now = utcnow


class GraphNodeModel(Base):
    __tablename__ = 'graph_nodes_v1'
    __table_args__ = (
        UniqueConstraint('workspace_id', 'entity_type', 'entity_id', name='uq_graph_node_scope_entity'),
        Index('ix_graph_nodes_scope_type', 'workspace_id', 'entity_type'),
        Index('ix_graph_nodes_label', 'label'),
    )

    id: Mapped[str] = mapped_column(String(180), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    entity_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    entity_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    label: Mapped[str] = mapped_column(String(240), default='', nullable=False)
    content_text: Mapped[str] = mapped_column(Text, default='', nullable=False)
    tags_json: Mapped[str] = mapped_column(Text, default='[]', nullable=False)
    metadata_json: Mapped[str] = mapped_column(Text, default='{}', nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    degree_cache: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class GraphRelationshipModel(Base):
    __tablename__ = 'graph_relationships_v1'
    __table_args__ = (
        UniqueConstraint('workspace_id', 'source_node_id', 'target_node_id', 'relationship_type', name='uq_graph_relationship'),
        Index('ix_graph_relationships_source', 'workspace_id', 'source_node_id'),
        Index('ix_graph_relationships_target', 'workspace_id', 'target_node_id'),
        Index('ix_graph_relationships_type', 'workspace_id', 'relationship_type'),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    source_node_id: Mapped[str] = mapped_column(String(180), nullable=False)
    target_node_id: Mapped[str] = mapped_column(String(180), nullable=False)
    relationship_type: Mapped[str] = mapped_column(String(80), nullable=False)
    weight: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    confidence: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, default='', nullable=False)
    source: Mapped[str] = mapped_column(String(32), default='manual', nullable=False)
    metadata_json: Mapped[str] = mapped_column(Text, default='{}', nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class GraphSuggestionModel(Base):
    __tablename__ = 'graph_suggestions_v1'
    __table_args__ = (
        UniqueConstraint('workspace_id', 'source_node_id', 'target_node_id', 'relationship_type', name='uq_graph_suggestion'),
        Index('ix_graph_suggestions_status', 'workspace_id', 'status'),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), default='', nullable=False, index=True)
    source_node_id: Mapped[str] = mapped_column(String(180), nullable=False)
    target_node_id: Mapped[str] = mapped_column(String(180), nullable=False)
    relationship_type: Mapped[str] = mapped_column(String(80), nullable=False)
    score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, default='', nullable=False)
    status: Mapped[str] = mapped_column(String(16), default='pending', nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)
