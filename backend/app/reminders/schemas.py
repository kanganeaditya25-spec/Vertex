from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


ReminderStatus = Literal["scheduled", "triggered", "completed", "dismissed", "skipped", "archived"]


class ReminderBase(BaseModel):
    title: str = Field(min_length=1, max_length=240)
    description: str = ""
    linked_module: str = "system"
    linked_item_id: str = ""
    workspace_id: str = ""
    project_id: str = ""
    goal_id: str = ""
    category: str = "general"
    priority: int = Field(default=3, ge=1, le=5)
    trigger_type: str = "time"
    trigger_at: datetime | None = None
    next_trigger_at: datetime | None = None
    repeat_rule: dict[str, Any] = Field(default_factory=dict)
    notification_type: str = "local"
    sound: bool = True
    vibration: bool = True
    icon: str = "notifications"
    color: str = "#2563EB"
    ai_generated: bool = False
    location_context: str = ""
    locked: bool = False
    hidden: bool = False
    source_rule: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class ReminderCreate(ReminderBase):
    pass


class ReminderUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=240)
    description: str | None = None
    category: str | None = None
    priority: int | None = Field(default=None, ge=1, le=5)
    trigger_type: str | None = None
    trigger_at: datetime | None = None
    next_trigger_at: datetime | None = None
    repeat_rule: dict[str, Any] | None = None
    notification_type: str | None = None
    sound: bool | None = None
    vibration: bool | None = None
    icon: str | None = None
    color: str | None = None
    location_context: str | None = None
    locked: bool | None = None
    hidden: bool | None = None
    source_rule: str | None = None
    metadata: dict[str, Any] | None = None


class ReminderRead(ReminderBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: ReminderStatus
    snoozed_count: int
    completed_at: datetime | None
    last_triggered_at: datetime | None
    created_at: datetime
    modified_at: datetime


class ReminderHistoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    reminder_id: str
    action: str
    occurred_at: datetime
    from_at: datetime | None
    to_at: datetime | None
    reason: str
    metadata: dict[str, Any] = Field(default_factory=dict)


class SnoozeRequest(BaseModel):
    minutes: int = Field(gt=0, le=60 * 24 * 365)
    reason: str = "user_snooze"


class RescheduleRequest(BaseModel):
    trigger_at: datetime
    reason: str = "user_reschedule"


class ReminderAction(BaseModel):
    action: Literal["complete", "skip", "archive", "dismiss", "delete", "duplicate"]
    reason: str = "user_action"


class BulkReminderAction(BaseModel):
    reminder_ids: list[str] = Field(min_length=1, max_length=10_000)
    action: Literal["complete", "snooze", "archive", "delete", "skip"]
    snooze_minutes: int | None = Field(default=None, gt=0, le=60 * 24 * 365)
    reason: str = "bulk_action"


class ReminderPreferences(BaseModel):
    local_enabled: bool = True
    silent_mode: bool = False
    quiet_hours_enabled: bool = False
    quiet_start_minutes: int = Field(default=22 * 60, ge=0, le=1439)
    quiet_end_minutes: int = Field(default=7 * 60, ge=0, le=1439)
    focus_sessions_enabled: bool = True
    sleep_schedule_enabled: bool = False
    work_hours_enabled: bool = False
    work_start_minutes: int = Field(default=9 * 60, ge=0, le=1439)
    work_end_minutes: int = Field(default=17 * 60, ge=0, le=1439)
    calendar_awareness: bool = True
    metadata: dict[str, Any] = Field(default_factory=dict)


class ReminderGroup(BaseModel):
    key: str
    label: str
    count: int
    reminders: list[ReminderRead]


class ReminderStats(BaseModel):
    total: int
    active: int
    completed: int
    dismissed: int
    overdue: int
    snooze_rate: float
    completion_rate: float
    missed_rate: float
    best_reminder_hour: int | None = None


class SmartSuggestion(BaseModel):
    reminder_id: str
    recommendation: str
    reason: str
    suggested_trigger_at: datetime | None = None
    confidence: float = Field(ge=0, le=1)


class DueReminder(BaseModel):
    reminder: ReminderRead
    delayed: bool = False
    delay_reason: str = ""


class ReminderEvent(BaseModel):
    event_name: str = Field(min_length=1, max_length=120)
    payload: dict[str, Any] = Field(default_factory=dict)
