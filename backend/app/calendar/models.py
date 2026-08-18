from datetime import UTC, datetime
from enum import StrEnum
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


def utc_now() -> datetime:
    return datetime.now(UTC)


class EventStatus(StrEnum):
    SCHEDULED = "scheduled"
    CONFIRMED = "confirmed"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    ARCHIVED = "archived"


class EventType(StrEnum):
    MEETING = "meeting"
    TASK_BLOCK = "task_block"
    FOCUS_BLOCK = "focus_block"
    DEEP_WORK = "deep_work"
    BREAK = "break"
    EXERCISE = "exercise"
    STUDY = "study"
    TRAVEL = "travel"
    SLEEP = "sleep"
    MEAL = "meal"
    CUSTOM = "custom"


class EventPriority(StrEnum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class EventModel(Base):
    __tablename__ = "events_v4"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    event_type: Mapped[str] = mapped_column(String(32), default=EventType.CUSTOM.value, index=True)
    category: Mapped[str] = mapped_column(String(80), default="general", index=True)
    priority: Mapped[str] = mapped_column(String(24), default=EventPriority.MEDIUM.value, index=True)
    status: Mapped[str] = mapped_column(String(24), default=EventStatus.SCHEDULED.value, index=True)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    location: Mapped[Optional[str]] = mapped_column(String(240), nullable=True)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    reminder_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    recurrence_rule_id: Mapped[Optional[str]] = mapped_column(ForeignKey("recurring_rules_v4.id"), nullable=True, index=True)
    color: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    icon: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    task_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True, index=True)
    project_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True, index=True)
    goal_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True, index=True)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    estimated_minutes: Mapped[int] = mapped_column(Integer, default=0)
    actual_minutes: Mapped[int] = mapped_column(Integer, default=0)
    focus_type: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    energy_level: Mapped[str] = mapped_column(String(24), default="medium")
    travel_buffer_minutes: Mapped[int] = mapped_column(Integer, default=0)
    preparation_buffer_minutes: Mapped[int] = mapped_column(Integer, default=0)
    cleanup_buffer_minutes: Mapped[int] = mapped_column(Integer, default=0)
    ai_scheduled: Mapped[bool] = mapped_column(Boolean, default=False)
    locked: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    flexible: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    recurring: Mapped[bool] = mapped_column(Boolean, default=False)
    all_day: Mapped[bool] = mapped_column(Boolean, default=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    version: Mapped[int] = mapped_column(Integer, default=1)
    sync_status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    recurrence_rule: Mapped[Optional["RecurringRuleModel"]] = relationship(back_populates="events")
    history: Mapped[list["EventHistoryModel"]] = relationship(cascade="all, delete-orphan", order_by="EventHistoryModel.created_at")
    reminders: Mapped[list["ReminderModel"]] = relationship(cascade="all, delete-orphan", order_by="ReminderModel.remind_at")
    focus_block: Mapped[Optional["FocusBlockModel"]] = relationship(back_populates="event", uselist=False, cascade="all, delete-orphan")


class RecurringRuleModel(Base):
    __tablename__ = "recurring_rules_v4"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    frequency: Mapped[str] = mapped_column(String(24), nullable=False)
    interval: Mapped[int] = mapped_column(Integer, default=1)
    weekdays: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)

    events: Mapped[list[EventModel]] = relationship(back_populates="recurrence_rule")


class CalendarPreferenceModel(Base):
    __tablename__ = "calendar_preferences_v4"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    default_view: Mapped[str] = mapped_column(String(24), default="agenda")
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    work_start_minute: Mapped[int] = mapped_column(Integer, default=9 * 60)
    work_end_minute: Mapped[int] = mapped_column(Integer, default=17 * 60)
    lunch_start_minute: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    lunch_end_minute: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    first_day_of_week: Mapped[int] = mapped_column(Integer, default=1)
    focus_start_minute: Mapped[int] = mapped_column(Integer, default=9 * 60)
    focus_end_minute: Mapped[int] = mapped_column(Integer, default=12 * 60)
    quiet_start_minute: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    quiet_end_minute: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    density: Mapped[str] = mapped_column(String(24), default="comfortable")
    reduced_motion: Mapped[bool] = mapped_column(Boolean, default=False)
    high_contrast: Mapped[bool] = mapped_column(Boolean, default=False)
    weekend_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)


class EventHistoryModel(Base):
    __tablename__ = "event_history_v4"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(ForeignKey("events_v4.id", ondelete="CASCADE"), index=True)
    action: Mapped[str] = mapped_column(String(48), nullable=False)
    details: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True)


class ReminderModel(Base):
    __tablename__ = "reminders_v4"
    __table_args__ = (UniqueConstraint("event_id", "remind_at", name="uq_event_reminder"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(ForeignKey("events_v4.id", ondelete="CASCADE"), index=True)
    remind_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    mode: Mapped[str] = mapped_column(String(24), default="silent")
    delivered: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class FocusBlockModel(Base):
    __tablename__ = "focus_blocks_v4"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(ForeignKey("events_v4.id", ondelete="CASCADE"), unique=True)
    planned_minutes: Mapped[int] = mapped_column(Integer, default=50)
    actual_minutes: Mapped[int] = mapped_column(Integer, default=0)
    break_minutes: Mapped[int] = mapped_column(Integer, default=10)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now)

    event: Mapped[EventModel] = relationship(back_populates="focus_block")


class EventSyncQueueModel(Base):
    __tablename__ = "event_sync_queue_v4"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(String(36), index=True)
    operation: Mapped[str] = mapped_column(String(24), nullable=False)
    payload: Mapped[str] = mapped_column(Text, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
