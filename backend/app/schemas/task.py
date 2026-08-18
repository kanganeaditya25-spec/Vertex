from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ChecklistItemInput(BaseModel):
    text: str = Field(min_length=1, max_length=240)
    position: int = Field(default=0, ge=0)


class ChecklistItemRead(ChecklistItemInput):
    model_config = ConfigDict(from_attributes=True)

    id: str
    completed: bool
    created_at: datetime
    completed_at: Optional[datetime] = None


class TaskBase(BaseModel):
    title: str = Field(min_length=1, max_length=240)
    description: str = Field(default="", max_length=20_000)
    status: str = "inbox"
    priority: str = "medium"
    category: str = Field(default="general", max_length=80)
    project: Optional[str] = Field(default=None, max_length=120)
    workspace: Optional[str] = Field(default=None, max_length=120)
    estimated_minutes: int = Field(default=0, ge=0, le=100_000)
    deadline: Optional[datetime] = None
    reminder_at: Optional[datetime] = None
    repeat_rule: Optional[str] = Field(default=None, max_length=240)
    location: Optional[str] = Field(default=None, max_length=240)
    energy_level: str = "medium"
    difficulty: str = "normal"
    importance_score: float = Field(default=50, ge=0, le=100)
    goal_id: Optional[str] = None
    parent_task_id: Optional[str] = None
    tags: list[str] = Field(default_factory=list, max_length=30)
    checklist: list[ChecklistItemInput] = Field(default_factory=list, max_length=200)
    pinned: bool = False
    favorite: bool = False
    private: bool = False
    color: Optional[str] = Field(default=None, max_length=32)
    icon: Optional[str] = Field(default=None, max_length=64)


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=240)
    description: Optional[str] = Field(default=None, max_length=20_000)
    status: Optional[str] = None
    priority: Optional[str] = None
    category: Optional[str] = Field(default=None, max_length=80)
    project: Optional[str] = Field(default=None, max_length=120)
    workspace: Optional[str] = Field(default=None, max_length=120)
    estimated_minutes: Optional[int] = Field(default=None, ge=0, le=100_000)
    actual_minutes: Optional[int] = Field(default=None, ge=0, le=100_000)
    deadline: Optional[datetime] = None
    reminder_at: Optional[datetime] = None
    repeat_rule: Optional[str] = Field(default=None, max_length=240)
    location: Optional[str] = Field(default=None, max_length=240)
    energy_level: Optional[str] = None
    difficulty: Optional[str] = None
    importance_score: Optional[float] = Field(default=None, ge=0, le=100)
    goal_id: Optional[str] = None
    parent_task_id: Optional[str] = None
    tags: Optional[list[str]] = Field(default=None, max_length=30)
    checklist: Optional[list[ChecklistItemInput]] = Field(default=None, max_length=200)
    pinned: Optional[bool] = None
    favorite: Optional[bool] = None
    hidden: Optional[bool] = None
    private: Optional[bool] = None
    color: Optional[str] = Field(default=None, max_length=32)
    icon: Optional[str] = Field(default=None, max_length=64)


class TagRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    color: Optional[str] = None


class TaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: str
    status: str
    priority: str
    category: str
    project: Optional[str]
    workspace: Optional[str]
    estimated_minutes: int
    actual_minutes: int
    deadline: Optional[datetime]
    reminder_at: Optional[datetime]
    repeat_rule: Optional[str]
    location: Optional[str]
    energy_level: str
    difficulty: str
    importance_score: float
    ai_score: float
    risk_score: float
    completion_percent: float
    parent_task_id: Optional[str]
    goal_id: Optional[str]
    pinned: bool
    favorite: bool
    hidden: bool
    private: bool
    shared: bool
    ai_generated: bool
    sync_status: str
    version: int
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime]
    archived_at: Optional[datetime]
    deleted_at: Optional[datetime]
    tags: list[TagRead] = Field(default_factory=list)
    checklist: list[ChecklistItemRead] = Field(default_factory=list)
    child_count: int = 0
    dependency_count: int = 0
    explanation: str = ""


class TaskHistoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    task_id: str
    action: str
    details: str
    actor: Optional[str]
    created_at: datetime


class BulkTaskAction(BaseModel):
    task_ids: list[str] = Field(min_length=1, max_length=500)
    action: str


class TaskStatistics(BaseModel):
    total: int
    completed: int
    remaining: int
    overdue: int
    estimated_minutes: int
    urgent: int
    completion_percent: float
