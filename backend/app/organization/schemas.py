from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

Status = Literal["planning", "active", "on_hold", "waiting", "completed", "cancelled", "archived"]
Priority = Literal["low", "medium", "high", "urgent"]
GoalType = Literal["daily", "weekly", "monthly", "quarterly", "yearly", "long_term"]


class OrganizationModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


def _clamp_progress(value: float) -> float:
    return max(0.0, min(100.0, value))


class WorkspaceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=180)
    description: str = ""
    icon: str = "workspaces"
    cover_image: str | None = None
    color: str = "#4F46E5"
    owner_id: str | None = None
    ai_context: str = ""
    settings: dict[str, Any] = Field(default_factory=dict)
    favorite: bool = False


class WorkspaceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    icon: str | None = None
    cover_image: str | None = None
    color: str | None = None
    ai_context: str | None = None
    settings: dict[str, Any] | None = None
    archived: bool | None = None
    favorite: bool | None = None


class WorkspaceRead(WorkspaceCreate, OrganizationModel):
    id: str
    archived: bool
    created_at: datetime
    updated_at: datetime


class ProjectCreate(BaseModel):
    workspace_id: str
    name: str = Field(min_length=1, max_length=180)
    description: str = ""
    cover: str | None = None
    icon: str = "folder_special"
    color: str = "#0F766E"
    status: Status = "planning"
    priority: Priority = "medium"
    start_date: date | None = None
    deadline: date | None = None
    estimated_minutes: int = Field(default=0, ge=0, le=10_000_000)
    progress: float = Field(default=0, ge=0, le=100)
    budget: float | None = Field(default=None, ge=0)
    tags: list[str] = Field(default_factory=list)
    category: str = "general"
    owner_id: str | None = None
    linked_goal_ids: list[str] = Field(default_factory=list)
    linked_task_ids: list[str] = Field(default_factory=list)
    linked_note_ids: list[str] = Field(default_factory=list)
    linked_event_ids: list[str] = Field(default_factory=list)
    ai_summary: str = ""
    favorite: bool = False
    locked: bool = False

    @field_validator("progress")
    @classmethod
    def normalized_progress(cls, value: float) -> float:
        return _clamp_progress(value)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    cover: str | None = None
    icon: str | None = None
    color: str | None = None
    status: Status | None = None
    priority: Priority | None = None
    start_date: date | None = None
    deadline: date | None = None
    estimated_minutes: int | None = Field(default=None, ge=0, le=10_000_000)
    progress: float | None = Field(default=None, ge=0, le=100)
    budget: float | None = Field(default=None, ge=0)
    tags: list[str] | None = None
    category: str | None = None
    linked_goal_ids: list[str] | None = None
    linked_task_ids: list[str] | None = None
    linked_note_ids: list[str] | None = None
    linked_event_ids: list[str] | None = None
    ai_summary: str | None = None
    archived: bool | None = None
    favorite: bool | None = None
    locked: bool | None = None

    @field_validator("progress")
    @classmethod
    def normalized_progress(cls, value: float | None) -> float | None:
        return None if value is None else _clamp_progress(value)


class ProjectRead(ProjectCreate, OrganizationModel):
    id: str
    archived: bool
    created_at: datetime
    updated_at: datetime


class GoalCreate(BaseModel):
    workspace_id: str | None = None
    title: str = Field(min_length=1, max_length=180)
    description: str = ""
    goal_type: GoalType = "weekly"
    target_date: date | None = None
    progress: float = Field(default=0, ge=0, le=100)
    linked_project_ids: list[str] = Field(default_factory=list)
    linked_task_ids: list[str] = Field(default_factory=list)
    linked_habit_ids: list[str] = Field(default_factory=list)
    priority: Priority = "medium"
    category: str = "general"


class GoalUpdate(BaseModel):
    workspace_id: str | None = None
    title: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    goal_type: GoalType | None = None
    target_date: date | None = None
    progress: float | None = Field(default=None, ge=0, le=100)
    linked_project_ids: list[str] | None = None
    linked_task_ids: list[str] | None = None
    linked_habit_ids: list[str] | None = None
    priority: Priority | None = None
    category: str | None = None
    archived: bool | None = None


class GoalRead(GoalCreate, OrganizationModel):
    id: str
    archived: bool
    created_at: datetime
    updated_at: datetime


class MilestoneCreate(BaseModel):
    project_id: str
    name: str = Field(min_length=1, max_length=180)
    deadline: date | None = None
    progress: float = Field(default=0, ge=0, le=100)
    task_ids: list[str] = Field(default_factory=list)
    dependency_ids: list[str] = Field(default_factory=list)


class MilestoneUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    deadline: date | None = None
    progress: float | None = Field(default=None, ge=0, le=100)
    task_ids: list[str] | None = None
    dependency_ids: list[str] | None = None
    completed: bool | None = None


class MilestoneRead(MilestoneCreate, OrganizationModel):
    id: str
    completed: bool
    created_at: datetime
    updated_at: datetime


class ProjectTemplateCreate(BaseModel):
    name: str = Field(min_length=1, max_length=180)
    category: str = "general"
    description: str = ""
    milestone_names: list[str] = Field(default_factory=list)


class ProjectTemplateRead(ProjectTemplateCreate, OrganizationModel):
    id: str
    created_at: datetime


class WorkspaceSummary(OrganizationModel):
    workspace: WorkspaceRead
    project_count: int
    active_project_count: int
    goal_count: int
    deadline_risk_count: int
    average_progress: float


class ProjectDashboard(OrganizationModel):
    project: ProjectRead
    milestones: list[MilestoneRead]
    linked_goals: list[GoalRead]
    task_count: int
    completed_task_count: int
    average_milestone_progress: float
    deadline_risk: str
    recent_activity: list[str]
    ai_summary: str
    recommendations: list[str]


class OrganizationSearchResult(OrganizationModel):
    entity_type: Literal["workspace", "project", "goal", "milestone"]
    entity_id: str
    title: str
    subtitle: str
    status: str
    route: str
    score: float


class OrganizationSearchResponse(BaseModel):
    query: str
    results: list[OrganizationSearchResult]


class OrganizationStats(BaseModel):
    workspace_count: int
    project_count: int
    active_project_count: int
    completed_project_count: int
    goal_count: int
    milestone_count: int
    deadline_risk_count: int
    average_project_progress: float


class ProjectIntelligence(BaseModel):
    project_id: str
    summary: str
    deadline_risk: Literal["none", "low", "medium", "high"]
    confidence: float
    recommendations: list[str]
    explanation: str
