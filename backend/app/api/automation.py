from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.automation.engine import DESTRUCTIVE_ACTIONS, conditions_match, suggest_workflow, trigger_matches, validate_workflow
from app.automation.models import AutomationEvent, AutomationExecution, AutomationTemplate, Workflow
from app.automation.schemas import (
    AutomationEventCreate,
    AutomationEventRead,
    AutomationStats,
    ExecutionRead,
    RunRequest,
    ValidationResult,
    WorkflowAction,
    WorkflowCreate,
    WorkflowRead,
    WorkflowSuggestionRequest,
    WorkflowSuggestionResponse,
    WorkflowTemplateCreate,
    WorkflowTemplateRead,
    WorkflowUpdate,
)
from app.calendar.models import EventModel
from app.db.session import get_db
from app.models.task import TaskModel
from app.notes.models import NoteModel

router = APIRouter(prefix="/automation", tags=["automation"])


def _now() -> datetime:
    return datetime.now(UTC)


DEFAULT_TEMPLATES = (
    ("Daily Planning", "planning", "Create a daily planning workflow.", {"workflow_type": "scheduled", "trigger_type": "scheduled", "trigger_config": {"schedule": "daily"}, "actions": [{"action_type": "create_task", "label": "Create daily planning task", "parameters": {"title": "Daily planning"}}]}),
    ("Weekly Review", "planning", "Review completed work every Friday.", {"workflow_type": "recurring", "trigger_type": "scheduled", "trigger_config": {"schedule": "weekly", "weekday": "friday"}, "actions": [{"action_type": "generate_ai_summary", "label": "Summarize the week"}]}),
    ("Project Kickoff", "projects", "Create a kickoff task after a project is created.", {"workflow_type": "event", "trigger_type": "project_created", "actions": [{"action_type": "create_task", "label": "Create kickoff task", "parameters": {"title": "Kick off {{event.project_name}}"}}]}),
    ("Study Routine", "learning", "Create a study task when a study event completes.", {"workflow_type": "event", "trigger_type": "calendar_event_finished", "conditions": [{"field": "event.category", "operator": "equals", "value": "study"}], "actions": [{"action_type": "create_task", "label": "Create revision task", "parameters": {"title": "Review {{event.title}}"}}]}),
    ("Workout Routine", "health", "Create the next workout task after completion.", {"workflow_type": "event", "trigger_type": "task_completed", "conditions": [{"field": "event.category", "operator": "equals", "value": "fitness"}], "actions": [{"action_type": "create_task", "label": "Create next workout", "parameters": {"title": "Next workout"}}]}),
    ("Deadline Follow-up", "projects", "Notify locally when a deadline is missed.", {"workflow_type": "event", "trigger_type": "deadline_missed", "actions": [{"action_type": "send_local_notification", "label": "Deadline missed"}]}),
    ("Meeting Preparation", "calendar", "Create preparation work before a meeting.", {"workflow_type": "event", "trigger_type": "calendar_event_created", "actions": [{"action_type": "create_task", "label": "Prepare for meeting", "parameters": {"title": "Prepare for {{event.title}}"}}]}),
    ("Note Backup", "notes", "Export a note after it is created.", {"workflow_type": "event", "trigger_type": "note_created", "actions": [{"action_type": "export_data", "label": "Export note snapshot"}]}),
    ("Calendar Cleanup", "calendar", "Archive completed calendar events after a review.", {"workflow_type": "manual", "trigger_type": "manual", "actions": [{"action_type": "archive_event", "label": "Archive selected events"}]}),
    ("Habit Tracking", "habits", "Create a next action after a habit event.", {"workflow_type": "event", "trigger_type": "habit_completed", "actions": [{"action_type": "create_task", "label": "Create habit follow-up", "parameters": {"title": "Continue habit"}}]}),
)


def _workflow_dict(workflow: Workflow) -> dict[str, Any]:
    return {
        "name": workflow.name,
        "workflow_type": workflow.workflow_type,
        "trigger_type": workflow.trigger_type,
        "trigger_config": workflow.trigger_config or {},
        "conditions": workflow.conditions or [],
        "actions": workflow.actions or [],
        "nodes": workflow.nodes or [],
        "edges": workflow.edges or [],
        "approval_mode": workflow.approval_mode,
        "max_steps": workflow.max_steps,
    }


def _workflow_or_404(db: Session, workflow_id: str) -> Workflow:
    workflow = db.get(Workflow, workflow_id)
    if workflow is None:
        raise HTTPException(status_code=404, detail=f"workflow '{workflow_id}' was not found")
    return workflow


def _template_text(value: str, event: dict[str, Any]) -> str:
    output = value
    for key, replacement in event.items():
        output = output.replace("{{event." + key + "}}", str(replacement))
    return output


def _destructive(workflow: Workflow) -> bool:
    return any(action.get("action_type") in DESTRUCTIVE_ACTIONS or action.get("requires_approval") for action in (workflow.actions or []))


def _execute_action(db: Session, action: dict[str, Any], event: dict[str, Any]) -> dict[str, Any]:
    action_type = action.get("action_type", "noop")
    parameters = action.get("parameters") or {}
    if action_type == "create_task":
        task = TaskModel(id=str(uuid4()), title=_template_text(str(parameters.get("title") or parameters.get("title_template") or "Automation task"), event), description=_template_text(str(parameters.get("description", "")), event), status=str(parameters.get("status", "inbox")), priority=str(parameters.get("priority", "medium")), category=str(parameters.get("category", "automation")), project=parameters.get("project_id") or event.get("project_id"), workspace=parameters.get("workspace_id") or event.get("workspace_id"), estimated_minutes=int(parameters.get("estimated_minutes", 0)))
        db.add(task)
        return {"action": action_type, "status": "success", "entity_id": task.id, "title": task.title}
    if action_type in {"update_task", "archive_task", "restore_task", "delete_task"}:
        task = db.get(TaskModel, parameters.get("task_id") or event.get("task_id"))
        if task is None:
            raise ValueError("target task was not found")
        if action_type == "archive_task":
            task.status = "archived"
            task.archived_at = _now()
        elif action_type == "restore_task":
            task.status = "inbox"
            task.archived_at = None
        elif action_type == "delete_task":
            task.status = "deleted"
            task.deleted_at = _now()
        else:
            for key in ("title", "description", "status", "priority", "category", "project", "workspace"):
                if key in parameters:
                    setattr(task, key, _template_text(str(parameters[key]), event))
        return {"action": action_type, "status": "success", "entity_id": task.id}
    if action_type == "create_event":
        start_at = datetime.fromisoformat(str(parameters.get("start_at", _now().isoformat())))
        end_at = datetime.fromisoformat(str(parameters.get("end_at", (start_at + timedelta(minutes=int(parameters.get("duration_minutes", 45)))).isoformat())))
        event_model = EventModel(id=str(uuid4()), title=_template_text(str(parameters.get("title") or parameters.get("title_template") or "Automation event"), event), description=str(parameters.get("description", "")), start_at=start_at, end_at=end_at, project_id=parameters.get("project_id") or event.get("project_id"), goal_id=parameters.get("goal_id") or event.get("goal_id"), category=str(parameters.get("category", "automation")), event_type="custom")
        db.add(event_model)
        return {"action": action_type, "status": "success", "entity_id": event_model.id, "title": event_model.title}
    if action_type == "create_note":
        title = _template_text(str(parameters.get("title") or parameters.get("title_template") or "Automation note"), event)
        content = _template_text(str(parameters.get("content", "")), event)
        note = NoteModel(id=str(uuid4()), title=title, plain_text=content, markdown_content=content, summary=content[:240], project_id=parameters.get("project_id") or event.get("project_id"), workspace=parameters.get("workspace_id") or event.get("workspace_id"))
        db.add(note)
        return {"action": action_type, "status": "success", "entity_id": note.id, "title": title}
    if action_type in {"notify", "send_local_notification", "generate_ai_summary", "generate_subtasks", "attach_asset", "export_data", "schedule", "noop"}:
        return {"action": action_type, "status": "logged", "message": _template_text(str(parameters.get("message", action.get("label", action_type))), event)}
    raise ValueError(f"unsupported action: {action_type}")


def _run(db: Session, workflow: Workflow, event: dict[str, Any], approval_granted: bool, replay_of: str | None = None) -> AutomationExecution:
    started = _now()
    execution = AutomationExecution(workflow_id=workflow.id, status="running", trigger_event=event, replay_of=replay_of, started_at=started)
    db.add(execution)
    db.flush()
    validation = validate_workflow(_workflow_dict(workflow))
    if not validation["valid"]:
        execution.status = "failed"
        execution.error = "; ".join(validation["errors"])
        execution.finished_at = _now()
        execution.duration_ms = int((execution.finished_at - started).total_seconds() * 1000)
        db.commit()
        return execution
    if not trigger_matches(workflow.trigger_type, str(event.get("event_type", "manual")), workflow.trigger_config or {}, event):
        execution.status = "skipped"
        execution.action_logs = [{"status": "skipped", "message": "Trigger did not match."}]
    elif not conditions_match(workflow.conditions or [], event):
        execution.status = "skipped"
        execution.action_logs = [{"status": "skipped", "message": "Conditions did not match."}]
    elif _destructive(workflow) and not approval_granted:
        execution.status = "pending_approval"
        execution.approval_required = True
        execution.action_logs = [{"status": "pending_approval", "message": "Approval is required before destructive or explicitly protected actions."}]
    else:
        logs: list[dict[str, Any]] = []
        try:
            for action in sorted(workflow.actions or [], key=lambda item: item.get("order", 0))[: workflow.max_steps]:
                logs.append(_execute_action(db, action, event))
            execution.status = "success"
            execution.action_logs = logs
            workflow.last_run_at = _now()
        except Exception as error:
            db.rollback()
            execution.status = "failed"
            execution.error = str(error)
            execution.action_logs = logs
    execution.finished_at = _now()
    execution.duration_ms = int((execution.finished_at - started).total_seconds() * 1000)
    db.commit()
    db.refresh(execution)
    return execution


def _ensure_templates(db: Session) -> None:
    if db.scalar(select(AutomationTemplate.id).limit(1)) is not None:
        return
    for name, category, description, definition in DEFAULT_TEMPLATES:
        db.add(AutomationTemplate(name=name, category=category, description=description, definition=definition, built_in=True))
    db.commit()


@router.get("/workflows", response_model=list[WorkflowRead])
def list_workflows(include_disabled: bool = True, db: Session = Depends(get_db)) -> list[Workflow]:
    statement = select(Workflow).order_by(Workflow.updated_at.desc())
    if not include_disabled:
        statement = statement.where(Workflow.enabled.is_(True))
    return list(db.scalars(statement).all())


@router.post("/workflows", response_model=WorkflowRead, status_code=status.HTTP_201_CREATED)
def create_workflow(payload: WorkflowCreate, db: Session = Depends(get_db)) -> Workflow:
    definition = payload.model_dump(mode="json")
    validation = validate_workflow(definition)
    if not validation["valid"]:
        raise HTTPException(status_code=422, detail=validation["errors"])
    workflow = Workflow(**definition)
    db.add(workflow)
    db.commit()
    db.refresh(workflow)
    return workflow


@router.get("/workflows/{workflow_id}", response_model=WorkflowRead)
def get_workflow(workflow_id: str, db: Session = Depends(get_db)) -> Workflow:
    return _workflow_or_404(db, workflow_id)


@router.patch("/workflows/{workflow_id}", response_model=WorkflowRead)
def update_workflow(workflow_id: str, payload: WorkflowUpdate, db: Session = Depends(get_db)) -> Workflow:
    workflow = _workflow_or_404(db, workflow_id)
    values = payload.model_dump(exclude_unset=True, mode="json")
    candidate = _workflow_dict(workflow) | values
    validation = validate_workflow(candidate)
    if not validation["valid"]:
        raise HTTPException(status_code=422, detail=validation["errors"])
    for key, value in values.items():
        setattr(workflow, key, value)
    db.commit()
    db.refresh(workflow)
    return workflow


@router.delete("/workflows/{workflow_id}")
def delete_workflow(workflow_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    workflow = _workflow_or_404(db, workflow_id)
    workflow.enabled = False
    db.commit()
    return {"id": workflow.id, "enabled": False}


@router.post("/workflows/{workflow_id}/validate", response_model=ValidationResult)
def validate_workflow_route(workflow_id: str, db: Session = Depends(get_db)) -> ValidationResult:
    workflow = _workflow_or_404(db, workflow_id)
    return ValidationResult(**validate_workflow(_workflow_dict(workflow)))


@router.post("/workflows/{workflow_id}/run", response_model=ExecutionRead)
def run_workflow(workflow_id: str, payload: RunRequest, db: Session = Depends(get_db)) -> AutomationExecution:
    workflow = _workflow_or_404(db, workflow_id)
    return _run(db, workflow, {"event_type": "manual", **payload.payload}, payload.approval_granted, payload.replay_of)


@router.post("/events", response_model=list[ExecutionRead])
def emit_event(payload: AutomationEventCreate, db: Session = Depends(get_db)) -> list[AutomationExecution]:
    if payload.dedupe_key:
        existing = db.scalar(select(AutomationEvent).where(AutomationEvent.dedupe_key == payload.dedupe_key))
        if existing is not None:
            return []
    event = AutomationEvent(**payload.model_dump(mode="json"))
    db.add(event)
    db.flush()
    event_payload = {"event_type": payload.event_type, "source": payload.source, **payload.payload}
    workflows = list(db.scalars(select(Workflow).where(Workflow.enabled.is_(True))).all())
    executions = [_run(db, workflow, event_payload, False) for workflow in workflows if trigger_matches(workflow.trigger_type, payload.event_type, workflow.trigger_config or {}, event_payload)]
    event.status = "processed"
    event.processed_at = _now()
    event.attempts += 1
    db.commit()
    return executions


@router.get("/events", response_model=list[AutomationEventRead])
def list_events(limit: int = Query(default=50, ge=1, le=500), db: Session = Depends(get_db)) -> list[AutomationEvent]:
    return list(db.scalars(select(AutomationEvent).order_by(AutomationEvent.occurred_at.desc()).limit(limit)).all())


@router.get("/executions", response_model=list[ExecutionRead])
def list_executions(workflow_id: str | None = None, limit: int = Query(default=50, ge=1, le=500), db: Session = Depends(get_db)) -> list[AutomationExecution]:
    statement = select(AutomationExecution).order_by(AutomationExecution.started_at.desc()).limit(limit)
    if workflow_id:
        statement = statement.where(AutomationExecution.workflow_id == workflow_id)
    return list(db.scalars(statement).all())


@router.post("/executions/{execution_id}/replay", response_model=ExecutionRead)
def replay_execution(execution_id: str, payload: RunRequest, db: Session = Depends(get_db)) -> AutomationExecution:
    execution = db.get(AutomationExecution, execution_id)
    if execution is None:
        raise HTTPException(status_code=404, detail="execution was not found")
    return _run(db, _workflow_or_404(db, execution.workflow_id), execution.trigger_event, payload.approval_granted, execution.id)


@router.get("/templates", response_model=list[WorkflowTemplateRead])
def list_templates(db: Session = Depends(get_db)) -> list[AutomationTemplate]:
    _ensure_templates(db)
    return list(db.scalars(select(AutomationTemplate).order_by(AutomationTemplate.name)).all())


@router.post("/templates", response_model=WorkflowTemplateRead, status_code=status.HTTP_201_CREATED)
def create_template(payload: WorkflowTemplateCreate, db: Session = Depends(get_db)) -> AutomationTemplate:
    template = AutomationTemplate(**payload.model_dump())
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


@router.post("/suggest", response_model=WorkflowSuggestionResponse)
def suggest(payload: WorkflowSuggestionRequest) -> WorkflowSuggestionResponse:
    return WorkflowSuggestionResponse(**suggest_workflow(payload.prompt))


@router.get("/stats", response_model=AutomationStats)
def stats(db: Session = Depends(get_db)) -> AutomationStats:
    workflows = list(db.scalars(select(Workflow)).all())
    executions = list(db.scalars(select(AutomationExecution)).all())
    pending_events = db.scalar(select(func.count(AutomationEvent.id)).where(AutomationEvent.status == "pending")) or 0
    return AutomationStats(workflow_count=len(workflows), enabled_workflow_count=sum(item.enabled for item in workflows), execution_count=len(executions), success_count=sum(item.status == "success" for item in executions), failure_count=sum(item.status == "failed" for item in executions), pending_approval_count=sum(item.status == "pending_approval" for item in executions), pending_event_count=int(pending_events))
