from datetime import UTC, datetime
from enum import StrEnum
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


def utc_now() -> datetime:
    return datetime.now(UTC)


class TaskStatus(StrEnum):
    INBOX = "inbox"
    TODAY = "today"
    UPCOMING = "upcoming"
    SCHEDULED = "scheduled"
    WAITING = "waiting"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    ARCHIVED = "archived"
    DELETED = "deleted"


class TaskPriority(StrEnum):
    CRITICAL = "critical"
    URGENT = "urgent"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    SOMEDAY = "someday"


class TaskEnergy(StrEnum):
    VERY_LOW = "very_low"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    DEEP_WORK = "deep_work"


class TaskDifficulty(StrEnum):
    EASY = "easy"
    NORMAL = "normal"
    HARD = "hard"
    EXPERT = "expert"
    UNKNOWN = "unknown"


class TaskModel(Base):
    __tablename__ = "tasks_v3"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default=TaskStatus.INBOX.value, index=True)
    priority: Mapped[str] = mapped_column(String(32), default=TaskPriority.MEDIUM.value, index=True)
    category: Mapped[str] = mapped_column(String(80), default="general", index=True)
    project: Mapped[Optional[str]] = mapped_column(String(120), nullable=True, index=True)
    workspace: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    created_by: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    assigned_to: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    estimated_minutes: Mapped[int] = mapped_column(Integer, default=0)
    actual_minutes: Mapped[int] = mapped_column(Integer, default=0)
    deadline: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    reminder_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    repeat_rule: Mapped[Optional[str]] = mapped_column(String(240), nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(240), nullable=True)
    energy_level: Mapped[str] = mapped_column(String(32), default=TaskEnergy.MEDIUM.value)
    difficulty: Mapped[str] = mapped_column(String(32), default=TaskDifficulty.NORMAL.value)
    importance_score: Mapped[float] = mapped_column(default=50.0)
    ai_score: Mapped[float] = mapped_column(default=0.0)
    risk_score: Mapped[float] = mapped_column(default=0.0)
    completion_percent: Mapped[float] = mapped_column(default=0.0)
    parent_task_id: Mapped[Optional[str]] = mapped_column(ForeignKey("tasks_v3.id"), nullable=True, index=True)
    goal_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True, index=True)
    color: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    icon: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    pinned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    favorite: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    private: Mapped[bool] = mapped_column(Boolean, default=False)
    shared: Mapped[bool] = mapped_column(Boolean, default=False)
    ai_generated: Mapped[bool] = mapped_column(Boolean, default=False)
    sync_status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    parent: Mapped[Optional["TaskModel"]] = relationship(remote_side=[id], back_populates="children")
    children: Mapped[list["TaskModel"]] = relationship(back_populates="parent", cascade="all, delete-orphan")
    tags: Mapped[list["TagModel"]] = relationship(secondary="task_tags", back_populates="tasks")
    checklist: Mapped[list["ChecklistItemModel"]] = relationship(cascade="all, delete-orphan", order_by="ChecklistItemModel.position")
    history: Mapped[list["TaskHistoryModel"]] = relationship(cascade="all, delete-orphan", order_by="TaskHistoryModel.created_at")


class TagModel(Base):
    __tablename__ = "tags_v3"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True, nullable=False, index=True)
    color: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    tasks: Mapped[list[TaskModel]] = relationship(secondary="task_tags", back_populates="tags")


class TaskTagModel(Base):
    __tablename__ = "task_tags"
    __table_args__ = (UniqueConstraint("task_id", "tag_id", name="uq_task_tag"),)

    task_id: Mapped[str] = mapped_column(ForeignKey("tasks_v3.id", ondelete="CASCADE"), primary_key=True)
    tag_id: Mapped[str] = mapped_column(ForeignKey("tags_v3.id", ondelete="CASCADE"), primary_key=True)


class ChecklistItemModel(Base):
    __tablename__ = "checklist_items_v3"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    task_id: Mapped[str] = mapped_column(ForeignKey("tasks_v3.id", ondelete="CASCADE"), index=True)
    text: Mapped[str] = mapped_column(String(240), nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    position: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


class TaskHistoryModel(Base):
    __tablename__ = "task_history_v3"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    task_id: Mapped[str] = mapped_column(ForeignKey("tasks_v3.id", ondelete="CASCADE"), index=True)
    action: Mapped[str] = mapped_column(String(48), nullable=False)
    details: Mapped[str] = mapped_column(Text, default="", nullable=False)
    actor: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class TaskDependencyModel(Base):
    __tablename__ = "task_dependencies_v3"
    __table_args__ = (UniqueConstraint("task_id", "depends_on_id", name="uq_task_dependency"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    task_id: Mapped[str] = mapped_column(ForeignKey("tasks_v3.id", ondelete="CASCADE"), index=True)
    depends_on_id: Mapped[str] = mapped_column(ForeignKey("tasks_v3.id", ondelete="CASCADE"), index=True)
    relation: Mapped[str] = mapped_column(String(24), default="finish_to_start")


class TaskSyncQueueModel(Base):
    __tablename__ = "task_sync_queue_v3"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    task_id: Mapped[str] = mapped_column(String(36), index=True)
    operation: Mapped[str] = mapped_column(String(24), nullable=False)
    payload: Mapped[str] = mapped_column(Text, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
