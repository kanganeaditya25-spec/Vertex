from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def utc_now() -> datetime:
    return datetime.now(UTC)


class ReminderRecordModel(Base):
    __tablename__ = "reminders_v1"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    title: Mapped[str] = mapped_column(String(240), nullable=False, index=True)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    linked_module: Mapped[str] = mapped_column(String(40), default="system", nullable=False, index=True)
    linked_item_id: Mapped[str] = mapped_column(String(80), default="", nullable=False, index=True)
    workspace_id: Mapped[str] = mapped_column(String(80), default="", nullable=False, index=True)
    project_id: Mapped[str] = mapped_column(String(80), default="", nullable=False, index=True)
    goal_id: Mapped[str] = mapped_column(String(80), default="", nullable=False, index=True)
    category: Mapped[str] = mapped_column(String(80), default="general", nullable=False, index=True)
    priority: Mapped[int] = mapped_column(Integer, default=3, nullable=False, index=True)
    trigger_type: Mapped[str] = mapped_column(String(32), default="time", nullable=False, index=True)
    trigger_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    next_trigger_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    repeat_rule: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    notification_type: Mapped[str] = mapped_column(String(32), default="local", nullable=False)
    sound: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    vibration: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    icon: Mapped[str] = mapped_column(String(80), default="notifications", nullable=False)
    color: Mapped[str] = mapped_column(String(32), default="#2563EB", nullable=False)
    ai_generated: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(24), default="scheduled", nullable=False, index=True)
    location_context: Mapped[str] = mapped_column(String(32), default="", nullable=False)
    locked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    snoozed_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_triggered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    source_rule: Mapped[str] = mapped_column(String(160), default="", nullable=False)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False, index=True)
    modified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class ReminderHistoryModel(Base):
    __tablename__ = "reminder_history_v1"

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    reminder_id: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False, index=True)
    from_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    to_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reason: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)


class ReminderPreferenceModel(Base):
    __tablename__ = "reminder_preferences_v1"

    id: Mapped[str] = mapped_column(String(40), primary_key=True, default="default")
    local_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    silent_mode: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    quiet_hours_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    quiet_start_minutes: Mapped[int] = mapped_column(Integer, default=22 * 60, nullable=False)
    quiet_end_minutes: Mapped[int] = mapped_column(Integer, default=7 * 60, nullable=False)
    focus_sessions_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    sleep_schedule_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    work_hours_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    work_start_minutes: Mapped[int] = mapped_column(Integer, default=9 * 60, nullable=False)
    work_end_minutes: Mapped[int] = mapped_column(Integer, default=17 * 60, nullable=False)
    calendar_awareness: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    metadata_json: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    modified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)
