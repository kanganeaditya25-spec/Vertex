from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class AnalyticsModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class FocusSessionCreate(BaseModel):
    started_at: datetime
    ended_at: datetime | None = None
    minutes: int = Field(default=0, ge=0, le=24 * 60)
    session_type: str = "deep_work"
    interruptions: int = Field(default=0, ge=0, le=10_000)
    project_id: str | None = None
    goal_id: str | None = None
    completed: bool = False
    notes: str = ""


class FocusSessionRead(FocusSessionCreate, AnalyticsModel):
    id: str
    created_at: datetime


class AnalyticsFilters(BaseModel):
    period: Literal["daily", "weekly", "monthly", "yearly"] = "weekly"
    start: datetime | None = None
    end: datetime | None = None
    workspace_id: str | None = None
    project_id: str | None = None
    goal_id: str | None = None


class MetricPoint(BaseModel):
    label: str
    value: float
    secondary_value: float | None = None


class BreakdownItem(BaseModel):
    label: str
    value: float
    percentage: float
    color: str


class AnalyticsDashboard(BaseModel):
    period: str
    range_start: datetime
    range_end: datetime
    productivity_score: float
    focus_score: float
    completion_rate: float
    goal_progress: float
    active_projects: int
    total_tasks: int
    completed_tasks: int
    overdue_tasks: int
    deep_work_minutes: int
    meeting_minutes: int
    learning_minutes: int
    notes_created: int
    knowledge_growth: float
    focus_sessions: int
    average_session_minutes: float
    weekly_summary: str
    monthly_summary: str
    score_explanation: str
    recommendations: list[str]
    daily_series: list[MetricPoint]
    task_breakdown: list[BreakdownItem]
    category_breakdown: list[BreakdownItem]
    focus_breakdown: list[BreakdownItem]


class AnalyticsReport(BaseModel):
    title: str
    period: str
    generated_at: datetime
    sections: list[dict[str, Any]]


class AnalyticsLayoutCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    widgets: list[dict[str, Any]] = Field(default_factory=list)


class AnalyticsLayoutRead(AnalyticsLayoutCreate, AnalyticsModel):
    id: str
    created_at: datetime
    updated_at: datetime


class AnalyticsInsight(BaseModel):
    kind: Literal["recommendation", "warning", "positive", "explanation"]
    title: str
    body: str
    confidence: float
    metric: str | None = None
