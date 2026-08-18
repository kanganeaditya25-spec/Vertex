from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def _id() -> str:
    return str(uuid4())


def _now() -> datetime:
    return datetime.now(UTC)


class Workflow(Base):
    __tablename__ = "automation_workflows"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    workflow_type: Mapped[str] = mapped_column(String(32), default="manual", nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    trigger_type: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    trigger_config: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    conditions: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    actions: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    variables: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    nodes: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    edges: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    approval_mode: Mapped[str] = mapped_column(String(32), default="destructive", nullable=False)
    retry_limit: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    timeout_seconds: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    max_steps: Mapped[int] = mapped_column(Integer, default=50, nullable=False)
    last_run_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now, nullable=False)


class AutomationTemplate(Base):
    __tablename__ = "automation_templates"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="general", nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    definition: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    built_in: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)


class AutomationExecution(Base):
    __tablename__ = "automation_executions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    workflow_id: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    trigger_event: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    action_logs: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    approval_required: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    replay_of: Mapped[str | None] = mapped_column(String(64), nullable=True)
    attempts: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_ms: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class AutomationEvent(Base):
    __tablename__ = "automation_events"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    event_type: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    source: Mapped[str] = mapped_column(String(80), default="system", nullable=False)
    dedupe_key: Mapped[str | None] = mapped_column(String(180), unique=True, nullable=True)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="pending", nullable=False, index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
