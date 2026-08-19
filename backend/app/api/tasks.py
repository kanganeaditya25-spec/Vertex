import json
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.event_bus.bus import DomainEvent, bus
from app.db.session import get_db
from app.models.task import (
    ChecklistItemModel,
    TagModel,
    TaskHistoryModel,
    TaskModel,
    TaskStatus,
    TaskSyncQueueModel,
)
from app.schemas.task import (
    BulkTaskAction,
    TaskCreate,
    TaskHistoryRead,
    TaskRead,
    TaskStatistics,
    TaskUpdate,
)
from app.services.task_intelligence import intelligence_service

router = APIRouter(prefix="/tasks", tags=["tasks"])


def _now() -> datetime:
    return datetime.now(UTC)


def _task_query():
    return select(TaskModel).options(selectinload(TaskModel.tags), selectinload(TaskModel.checklist))


def _find_task(db: Session, task_id: str, include_deleted: bool = False) -> TaskModel:
    statement = _task_query().where(TaskModel.id == task_id)
    if not include_deleted:
        statement = statement.where(TaskModel.deleted_at.is_(None))
    task = db.scalar(statement)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


def _serialize(task: TaskModel) -> dict:
    recommendation = intelligence_service.recommend(task)
    task.ai_score = recommendation.priority_score
    task.risk_score = recommendation.risk_score
    return {
        **TaskRead.model_validate(task).model_dump(mode="json"),
        "child_count": len(task.children),
        "dependency_count": 0,
        "explanation": recommendation.explanation,
    }


def _record(db: Session, task: TaskModel, action: str, details: str = "") -> None:
    db.add(TaskHistoryModel(id=str(uuid4()), task_id=task.id, action=action, details=details))


def _queue(db: Session, task: TaskModel, operation: str) -> None:
    payload = json.dumps({"id": task.id, "version": task.version, "operation": operation})
    db.add(TaskSyncQueueModel(id=str(uuid4()), task_id=task.id, operation=operation, payload=payload, version=task.version))


def _set_tags(db: Session, task: TaskModel, names: list[str]) -> None:
    task.tags.clear()
    for raw_name in dict.fromkeys(name.strip().lower() for name in names if name.strip()):
        tag = db.scalar(select(TagModel).where(TagModel.name == raw_name))
        if tag is None:
            tag = TagModel(id=str(uuid4()), name=raw_name)
            db.add(tag)
        task.tags.append(tag)


def _set_checklist(task: TaskModel, items: list[dict]) -> None:
    task.checklist.clear()
    for item in items:
        task.checklist.append(
            ChecklistItemModel(
                id=str(uuid4()),
                task_id=task.id,
                text=item["text"],
                position=item.get("position", 0),
            )
        )
    task.completion_percent = round(
        sum(bool(item.completed) for item in task.checklist) / len(task.checklist) * 100, 2
    ) if task.checklist else task.completion_percent


def _apply_recurrence(task: TaskModel) -> TaskModel | None:
    if not task.repeat_rule:
        return None
    rule = task.repeat_rule.lower()
    increments = {"daily": timedelta(days=1), "weekdays": timedelta(days=1), "weekly": timedelta(days=7), "biweekly": timedelta(days=14), "monthly": timedelta(days=30)}
    increment = increments.get(rule)
    if increment is None:
        return None
    next_deadline = task.deadline + increment if task.deadline else None
    return TaskModel(
        id=str(uuid4()),
        title=task.title,
        description=task.description,
        status=TaskStatus.SCHEDULED.value,
        priority=task.priority,
        category=task.category,
        project=task.project,
        workspace=task.workspace,
        estimated_minutes=task.estimated_minutes,
        deadline=next_deadline,
        repeat_rule=task.repeat_rule,
        energy_level=task.energy_level,
        difficulty=task.difficulty,
        importance_score=task.importance_score,
        goal_id=task.goal_id,
        pinned=task.pinned,
        favorite=task.favorite,
        private=task.private,
        color=task.color,
        icon=task.icon,
        sync_status="pending",
    )


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: Session = Depends(get_db)) -> dict:
    fields = payload.model_dump(exclude={"tags", "checklist"})
    task = TaskModel(id=str(uuid4()), **fields)
    db.add(task)
    db.flush()
    _set_tags(db, task, payload.tags)
    _set_checklist(task, [item.model_dump() for item in payload.checklist])
    _record(db, task, "created")
    _queue(db, task, "create")
    db.commit()
    return _serialize(_find_task(db, task.id))


@router.get("", response_model=list[TaskRead])
def list_tasks(
    search: str | None = None,
    status_filter: str | None = Query(default=None, alias="status"),
    priority: str | None = None,
    category: str | None = None,
    favorite: bool | None = None,
    pinned: bool | None = None,
    include_archived: bool = False,
    limit: int = Query(default=100, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[dict]:
    statement = _task_query().where(TaskModel.deleted_at.is_(None))
    if not include_archived:
        statement = statement.where(TaskModel.status != TaskStatus.ARCHIVED.value)
    if search:
        term = f"%{search.strip()}%"
        statement = statement.where(or_(TaskModel.title.ilike(term), TaskModel.description.ilike(term), TaskModel.category.ilike(term)))
    if status_filter:
        statement = statement.where(TaskModel.status == status_filter)
    if priority:
        statement = statement.where(TaskModel.priority == priority)
    if category:
        statement = statement.where(TaskModel.category == category)
    if favorite is not None:
        statement = statement.where(TaskModel.favorite == favorite)
    if pinned is not None:
        statement = statement.where(TaskModel.pinned == pinned)
    statement = statement.order_by(TaskModel.pinned.desc(), TaskModel.deadline.asc().nulls_last(), TaskModel.created_at.desc()).offset(offset).limit(limit)
    return [_serialize(task) for task in db.scalars(statement).unique().all()]


@router.get("/statistics", response_model=TaskStatistics)
def task_statistics(db: Session = Depends(get_db)) -> TaskStatistics:
    tasks = list(db.scalars(select(TaskModel).where(TaskModel.deleted_at.is_(None))))
    now = _now()
    completed = sum(task.status == TaskStatus.COMPLETED.value for task in tasks)
    overdue = sum(
        bool(
            task.deadline
            and (task.deadline if task.deadline.tzinfo else task.deadline.replace(tzinfo=UTC)) < now
            and task.status not in {TaskStatus.COMPLETED.value, TaskStatus.ARCHIVED.value}
        )
        for task in tasks
    )
    urgent = sum(task.priority in {"critical", "urgent"} for task in tasks)
    total = len(tasks)
    return TaskStatistics(
        total=total,
        completed=completed,
        remaining=total - completed,
        overdue=overdue,
        estimated_minutes=sum(task.estimated_minutes for task in tasks),
        urgent=urgent,
        completion_percent=round(completed / total * 100, 2) if total else 0,
    )


@router.get("/{task_id}", response_model=TaskRead)
def get_task(task_id: str, db: Session = Depends(get_db)) -> dict:
    return _serialize(_find_task(db, task_id))


@router.put("/{task_id}", response_model=TaskRead)
def update_task(task_id: str, payload: TaskUpdate, db: Session = Depends(get_db)) -> dict:
    task = _find_task(db, task_id)
    changes = payload.model_dump(exclude_unset=True)
    if task.status == TaskStatus.COMPLETED.value and changes and changes.get("status") != TaskStatus.INBOX.value:
        raise HTTPException(status_code=409, detail="Completed tasks must be reopened before editing")
    tags = changes.pop("tags", None)
    checklist = changes.pop("checklist", None)
    for key, value in changes.items():
        setattr(task, key, value)
    if tags is not None:
        _set_tags(db, task, tags)
    if checklist is not None:
        _set_checklist(task, checklist)
    if task.status == TaskStatus.COMPLETED.value:
        task.completed_at = task.completed_at or _now()
        task.completion_percent = 100
    elif "status" in changes:
        task.completed_at = None
    task.version += 1
    task.sync_status = "pending"
    _record(db, task, "edited", ",".join(changes.keys()))
    _queue(db, task, "update")
    db.commit()
    return _serialize(_find_task(db, task.id))


@router.delete("/{task_id}", response_model=TaskRead)
def delete_task(task_id: str, db: Session = Depends(get_db)) -> dict:
    task = _find_task(db, task_id)
    task.status = TaskStatus.DELETED.value
    task.deleted_at = _now()
    task.version += 1
    _record(db, task, "deleted")
    _queue(db, task, "delete")
    db.commit()
    return _serialize(task)


@router.post("/{task_id}/complete", response_model=TaskRead)
def complete_task(task_id: str, db: Session = Depends(get_db)) -> dict:
    task = _find_task(db, task_id)
    task.status = TaskStatus.COMPLETED.value
    task.completed_at = _now()
    task.completion_percent = 100
    task.version += 1
    _record(db, task, "completed")
    _queue(db, task, "complete")
    next_task = _apply_recurrence(task)
    if next_task is not None:
        db.add(next_task)
        _record(db, next_task, "created", "recurrence")
        _queue(db, next_task, "create")
    db.commit()
    bus.publish(DomainEvent("task.completed", {"task_id": task.id, "title": task.title, "project_id": task.project or "", "workspace_id": task.workspace or "", "goal_id": task.goal_id or "", "create_review_reminder": bool(task.repeat_rule), "review_after_minutes": 24 * 60}))
    return _serialize(_find_task(db, task.id))


@router.post("/{task_id}/archive", response_model=TaskRead)
def archive_task(task_id: str, db: Session = Depends(get_db)) -> dict:
    task = _find_task(db, task_id)
    task.status = TaskStatus.ARCHIVED.value
    task.archived_at = _now()
    task.version += 1
    _record(db, task, "archived")
    _queue(db, task, "archive")
    db.commit()
    return _serialize(_find_task(db, task.id))


@router.post("/{task_id}/restore", response_model=TaskRead)
def restore_task(task_id: str, db: Session = Depends(get_db)) -> dict:
    task = _find_task(db, task_id, include_deleted=True)
    task.status = TaskStatus.INBOX.value
    task.archived_at = None
    task.deleted_at = None
    task.version += 1
    _record(db, task, "restored")
    _queue(db, task, "restore")
    db.commit()
    return _serialize(_find_task(db, task.id))


@router.post("/{task_id}/duplicate", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def duplicate_task(task_id: str, db: Session = Depends(get_db)) -> dict:
    source = _find_task(db, task_id)
    duplicate = TaskModel(
        id=str(uuid4()),
        title=f"{source.title} (copy)",
        description=source.description,
        status=TaskStatus.INBOX.value,
        priority=source.priority,
        category=source.category,
        project=source.project,
        workspace=source.workspace,
        estimated_minutes=source.estimated_minutes,
        deadline=source.deadline,
        repeat_rule=source.repeat_rule,
        energy_level=source.energy_level,
        difficulty=source.difficulty,
        importance_score=source.importance_score,
        goal_id=source.goal_id,
        pinned=False,
        favorite=False,
        private=source.private,
        color=source.color,
        icon=source.icon,
    )
    db.add(duplicate)
    db.flush()
    _set_tags(db, duplicate, [tag.name for tag in source.tags])
    _record(db, duplicate, "created", f"duplicated_from:{source.id}")
    _queue(db, duplicate, "create")
    db.commit()
    return _serialize(_find_task(db, duplicate.id))


@router.post("/bulk", response_model=dict[str, int])
def bulk_action(payload: BulkTaskAction, db: Session = Depends(get_db)) -> dict[str, int]:
    allowed = {"complete", "archive", "delete", "restore", "favorite", "pin"}
    if payload.action not in allowed:
        raise HTTPException(status_code=422, detail=f"Unsupported bulk action: {payload.action}")
    tasks = list(db.scalars(select(TaskModel).where(TaskModel.id.in_(payload.task_ids))).all())
    now = _now()
    for task in tasks:
        if payload.action == "complete":
            task.status, task.completed_at, task.completion_percent = TaskStatus.COMPLETED.value, now, 100
        elif payload.action == "archive":
            task.status, task.archived_at = TaskStatus.ARCHIVED.value, now
        elif payload.action == "delete":
            task.status, task.deleted_at = TaskStatus.DELETED.value, now
        elif payload.action == "restore":
            task.status, task.deleted_at, task.archived_at = TaskStatus.INBOX.value, None, None
        elif payload.action == "favorite":
            task.favorite = not task.favorite
        elif payload.action == "pin":
            task.pinned = not task.pinned
        task.version += 1
        _record(db, task, payload.action)
        _queue(db, task, payload.action)
    db.commit()
    return {"updated": len(tasks)}


@router.get("/{task_id}/history", response_model=list[TaskHistoryRead])
def task_history(task_id: str, db: Session = Depends(get_db)) -> list[TaskHistoryModel]:
    _find_task(db, task_id, include_deleted=True)
    return list(db.scalars(select(TaskHistoryModel).where(TaskHistoryModel.task_id == task_id).order_by(TaskHistoryModel.created_at.desc())).all())
