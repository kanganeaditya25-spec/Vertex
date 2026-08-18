from __future__ import annotations

from datetime import UTC, date, datetime
from typing import Any
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, Float, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def _id() -> str:
    return str(uuid4())


def _now() -> datetime:
    return datetime.now(UTC)


class Workspace(Base):
    __tablename__ = "organization_workspaces"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    icon: Mapped[str] = mapped_column(String(80), default="workspaces", nullable=False)
    cover_image: Mapped[str | None] = mapped_column(String(500), nullable=True)
    color: Mapped[str] = mapped_column(String(32), default="#4F46E5", nullable=False)
    owner_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    ai_context: Mapped[str] = mapped_column(Text, default="", nullable=False)
    settings: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now, nullable=False)


class Project(Base):
    __tablename__ = "organization_projects"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    workspace_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    cover: Mapped[str | None] = mapped_column(String(500), nullable=True)
    icon: Mapped[str] = mapped_column(String(80), default="folder_special", nullable=False)
    color: Mapped[str] = mapped_column(String(32), default="#0F766E", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="planning", nullable=False, index=True)
    priority: Mapped[str] = mapped_column(String(24), default="medium", nullable=False)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    deadline: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    estimated_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    progress: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    budget: Mapped[float | None] = mapped_column(Float, nullable=True)
    tags: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="general", nullable=False)
    owner_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    linked_goal_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_task_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_note_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_event_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    ai_summary: Mapped[str] = mapped_column(Text, default="", nullable=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    locked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now, nullable=False)


class Goal(Base):
    __tablename__ = "organization_goals"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    workspace_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    goal_type: Mapped[str] = mapped_column(String(32), default="weekly", nullable=False)
    target_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    progress: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    linked_project_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_task_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    linked_habit_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    priority: Mapped[str] = mapped_column(String(24), default="medium", nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="general", nullable=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now, nullable=False)


class Milestone(Base):
    __tablename__ = "organization_milestones"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    project_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    deadline: Mapped[date | None] = mapped_column(Date, nullable=True)
    progress: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    task_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    dependency_ids: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now, nullable=False)


class ProjectTemplate(Base):
    __tablename__ = "organization_project_templates"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="general", nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    milestone_names: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)


class OrganizationSyncQueue(Base):
    __tablename__ = "organization_sync_queue"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    entity_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    entity_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    operation: Mapped[str] = mapped_column(String(24), nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, nullable=False)
    synced_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
