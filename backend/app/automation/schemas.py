from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


WorkflowType = Literal["one_time", "scheduled", "event", "manual", "recurring", "conditional", "multi_step"]
ApprovalMode = Literal["never", "destructive", "always"]
ConditionOperator = Literal["equals", "not_equals", "contains", "greater_than", "less_than", "greater_or_equal", "less_or_equal", "exists", "in"]
LogicalOperator = Literal["AND", "OR", "NOT"]


class Condition(BaseModel):
    field: str | None = Field(default=None, max_length=120)
    operator: ConditionOperator | None = None
    value: Any = None
    logical: LogicalOperator | None = None
    children: list["Condition"] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_shape(self) -> "Condition":
        if self.logical and not self.children:
            raise ValueError("logical conditions require children")
        if not self.logical and (not self.field or not self.operator):
            raise ValueError("leaf conditions require field and operator")
        if self.logical == "NOT" and len(self.children) != 1:
            raise ValueError("NOT conditions require exactly one child")
        return self


class WorkflowAction(BaseModel):
    action_type: str = Field(min_length=1, max_length=64)
    label: str = ""
    parameters: dict[str, Any] = Field(default_factory=dict)
    order: int = Field(default=0, ge=0, le=1000)
    requires_approval: bool = False
    retry_limit: int = Field(default=0, ge=0, le=5)


class WorkflowNode(BaseModel):
    id: str = Field(min_length=1, max_length=80)
    node_type: Literal["trigger", "condition", "action", "branch", "loop", "end"]
    label: str = ""
    data: dict[str, Any] = Field(default_factory=dict)
    position: dict[str, float] = Field(default_factory=dict)


class WorkflowEdge(BaseModel):
    source: str = Field(min_length=1, max_length=80)
    target: str = Field(min_length=1, max_length=80)
    label: str = ""


class WorkflowCreate(BaseModel):
    name: str = Field(min_length=1, max_length=180)
    description: str = ""
    workflow_type: WorkflowType = "manual"
    enabled: bool = True
    trigger_type: str = Field(min_length=1, max_length=64)
    trigger_config: dict[str, Any] = Field(default_factory=dict)
    conditions: list[Condition] = Field(default_factory=list)
    actions: list[WorkflowAction] = Field(default_factory=list)
    variables: dict[str, Any] = Field(default_factory=dict)
    nodes: list[WorkflowNode] = Field(default_factory=list)
    edges: list[WorkflowEdge] = Field(default_factory=list)
    approval_mode: ApprovalMode = "destructive"
    retry_limit: int = Field(default=0, ge=0, le=5)
    timeout_seconds: int = Field(default=30, ge=1, le=300)
    max_steps: int = Field(default=50, ge=1, le=500)


class WorkflowUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    workflow_type: WorkflowType | None = None
    enabled: bool | None = None
    trigger_type: str | None = Field(default=None, min_length=1, max_length=64)
    trigger_config: dict[str, Any] | None = None
    conditions: list[Condition] | None = None
    actions: list[WorkflowAction] | None = None
    variables: dict[str, Any] | None = None
    nodes: list[WorkflowNode] | None = None
    edges: list[WorkflowEdge] | None = None
    approval_mode: ApprovalMode | None = None
    retry_limit: int | None = Field(default=None, ge=0, le=5)
    timeout_seconds: int | None = Field(default=None, ge=1, le=300)
    max_steps: int | None = Field(default=None, ge=1, le=500)


class WorkflowRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    description: str
    workflow_type: str
    enabled: bool
    trigger_type: str
    trigger_config: dict[str, Any]
    conditions: list[dict[str, Any]]
    actions: list[dict[str, Any]]
    variables: dict[str, Any]
    nodes: list[dict[str, Any]]
    edges: list[dict[str, Any]]
    approval_mode: str
    retry_limit: int
    timeout_seconds: int
    max_steps: int
    last_run_at: datetime | None
    created_at: datetime
    updated_at: datetime


class WorkflowTemplateCreate(BaseModel):
    name: str = Field(min_length=1, max_length=180)
    category: str = "general"
    description: str = ""
    definition: dict[str, Any] = Field(default_factory=dict)


class WorkflowTemplateRead(WorkflowTemplateCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    built_in: bool
    created_at: datetime


class AutomationEventCreate(BaseModel):
    event_type: str = Field(min_length=1, max_length=80)
    source: str = "manual"
    dedupe_key: str | None = Field(default=None, max_length=180)
    payload: dict[str, Any] = Field(default_factory=dict)


class AutomationEventRead(AutomationEventCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: str
    attempts: int
    occurred_at: datetime
    processed_at: datetime | None


class RunRequest(BaseModel):
    approval_granted: bool = False
    payload: dict[str, Any] = Field(default_factory=dict)
    replay_of: str | None = None


class ExecutionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    workflow_id: str
    status: str
    trigger_event: dict[str, Any]
    action_logs: list[dict[str, Any]]
    error: str | None
    approval_required: bool
    replay_of: str | None
    attempts: int
    started_at: datetime
    finished_at: datetime | None
    duration_ms: int


class ValidationResult(BaseModel):
    valid: bool
    errors: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    step_count: int


class AutomationStats(BaseModel):
    workflow_count: int
    enabled_workflow_count: int
    execution_count: int
    success_count: int
    failure_count: int
    pending_approval_count: int
    pending_event_count: int


class WorkflowSuggestionRequest(BaseModel):
    prompt: str = Field(min_length=5, max_length=1000)


class WorkflowSuggestionResponse(BaseModel):
    name: str
    description: str
    workflow_type: WorkflowType
    trigger_type: str
    trigger_config: dict[str, Any]
    conditions: list[Condition]
    actions: list[WorkflowAction]
    explanation: str
