from datetime import datetime
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, model_validator


class RecurrenceInput(BaseModel):
    frequency: str = Field(min_length=1, max_length=24)
    interval: int = Field(default=1, ge=1, le=365)
    weekdays: Optional[list[int]] = None
    until: Optional[datetime] = None


class EventCreate(BaseModel):
    title: str = Field(min_length=1, max_length=240)
    description: str = Field(default="", max_length=20_000)
    event_type: str = "custom"
    category: str = Field(default="general", max_length=80)
    priority: str = "medium"
    status: str = "scheduled"
    start_at: datetime
    end_at: datetime
    timezone: str = "UTC"
    location: Optional[str] = Field(default=None, max_length=240)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    reminder_minutes: Optional[int] = Field(default=None, ge=0, le=10080)
    recurrence: Optional[RecurrenceInput] = None
    color: Optional[str] = Field(default=None, max_length=32)
    icon: Optional[str] = Field(default=None, max_length=64)
    task_id: Optional[str] = None
    project_id: Optional[str] = None
    goal_id: Optional[str] = None
    notes: str = Field(default="", max_length=20_000)
    estimated_minutes: int = Field(default=0, ge=0, le=100_000)
    focus_type: Optional[str] = Field(default=None, max_length=32)
    energy_level: str = "medium"
    travel_buffer_minutes: int = Field(default=0, ge=0, le=1440)
    preparation_buffer_minutes: int = Field(default=0, ge=0, le=1440)
    cleanup_buffer_minutes: int = Field(default=0, ge=0, le=1440)
    ai_scheduled: bool = False
    locked: bool = False
    flexible: bool = True
    all_day: bool = False

    @model_validator(mode="after")
    def validate_time(self) -> "EventCreate":
        if self.end_at <= self.start_at:
            raise ValueError("end_at must be after start_at")
        try:
            ZoneInfo(self.timezone)
        except ZoneInfoNotFoundError as error:
            raise ValueError("timezone is not recognized") from error
        if self.recurrence and self.recurrence.frequency not in {"daily", "weekly", "monthly", "weekdays"}:
            raise ValueError("unsupported recurrence frequency")
        return self


class EventUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=240)
    description: Optional[str] = Field(default=None, max_length=20_000)
    event_type: Optional[str] = None
    category: Optional[str] = Field(default=None, max_length=80)
    priority: Optional[str] = None
    status: Optional[str] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    timezone: Optional[str] = None
    location: Optional[str] = Field(default=None, max_length=240)
    reminder_minutes: Optional[int] = Field(default=None, ge=0, le=10080)
    color: Optional[str] = Field(default=None, max_length=32)
    notes: Optional[str] = Field(default=None, max_length=20_000)
    estimated_minutes: Optional[int] = Field(default=None, ge=0, le=100_000)
    actual_minutes: Optional[int] = Field(default=None, ge=0, le=100_000)
    energy_level: Optional[str] = None
    locked: Optional[bool] = None
    flexible: Optional[bool] = None
    completed: Optional[bool] = None


class EventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: str
    event_type: str
    category: str
    priority: str
    status: str
    start_at: datetime
    end_at: datetime
    timezone: str
    location: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    reminder_minutes: Optional[int]
    color: Optional[str]
    icon: Optional[str]
    task_id: Optional[str]
    project_id: Optional[str]
    goal_id: Optional[str]
    notes: str
    estimated_minutes: int
    actual_minutes: int
    focus_type: Optional[str]
    energy_level: str
    travel_buffer_minutes: int
    preparation_buffer_minutes: int
    cleanup_buffer_minutes: int
    ai_scheduled: bool
    locked: bool
    flexible: bool
    recurring: bool
    all_day: bool
    completed: bool
    version: int
    sync_status: str
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime]
    archived_at: Optional[datetime]


class EventHistoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    event_id: str
    action: str
    details: str
    created_at: datetime


class ConflictRead(BaseModel):
    conflict_type: str
    severity: str
    event_ids: list[str]
    message: str
    suggested_resolution: str


class ScheduleRequest(BaseModel):
    task_ids: list[str] = Field(default_factory=list, max_length=500)
    window_start: datetime
    window_end: datetime
    energy_level: str = "high"
    include_breaks: bool = True

    @model_validator(mode="after")
    def validate_window(self) -> "ScheduleRequest":
        if self.window_end <= self.window_start:
            raise ValueError("window_end must be after window_start")
        return self


class ScheduleSuggestion(BaseModel):
    task_id: str
    start_at: datetime
    end_at: datetime
    score: float
    explanation: str
    break_after_minutes: int = 0


class CalendarStatistics(BaseModel):
    total_events: int
    completed_events: int
    focus_minutes: int
    scheduled_minutes: int
    overdue_events: int
    conflicts: int
    free_minutes_today: int


class CalendarPreferenceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    default_view: str
    timezone: str
    work_start_minute: int
    work_end_minute: int
    lunch_start_minute: Optional[int]
    lunch_end_minute: Optional[int]
    first_day_of_week: int
    focus_start_minute: int
    focus_end_minute: int
    quiet_start_minute: Optional[int]
    quiet_end_minute: Optional[int]
    density: str
    reduced_motion: bool
    high_contrast: bool
    weekend_enabled: bool


class CalendarPreferenceUpdate(BaseModel):
    default_view: Optional[str] = None
    timezone: Optional[str] = None
    work_start_minute: Optional[int] = Field(default=None, ge=0, le=1439)
    work_end_minute: Optional[int] = Field(default=None, ge=1, le=1440)
    lunch_start_minute: Optional[int] = Field(default=None, ge=0, le=1439)
    lunch_end_minute: Optional[int] = Field(default=None, ge=1, le=1440)
    first_day_of_week: Optional[int] = Field(default=None, ge=0, le=6)
    focus_start_minute: Optional[int] = Field(default=None, ge=0, le=1439)
    focus_end_minute: Optional[int] = Field(default=None, ge=1, le=1440)
    density: Optional[str] = None
    reduced_motion: Optional[bool] = None
    high_contrast: Optional[bool] = None
    weekend_enabled: Optional[bool] = None
