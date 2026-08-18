from datetime import UTC, datetime, time, timedelta
import json
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.calendar.intelligence import intelligence_service
from app.calendar.models import (
    CalendarPreferenceModel,
    EventHistoryModel,
    EventModel,
    EventStatus,
    EventSyncQueueModel,
    RecurringRuleModel,
)
from app.calendar.schemas import (
    CalendarPreferenceRead,
    CalendarPreferenceUpdate,
    CalendarStatistics,
    ConflictRead,
    EventCreate,
    EventHistoryRead,
    EventRead,
    EventUpdate,
    ScheduleRequest,
    ScheduleSuggestion,
)
from app.db.session import get_db
from app.models.task import TaskModel

router = APIRouter(prefix="/calendar", tags=["calendar"])


def _now() -> datetime:
    return datetime.now(UTC)


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _get_event(db: Session, event_id: str, include_deleted: bool = False) -> EventModel:
    statement = select(EventModel).where(EventModel.id == event_id)
    if not include_deleted:
        statement = statement.where(EventModel.deleted_at.is_(None))
    event = db.scalar(statement)
    if event is None:
        raise HTTPException(status_code=404, detail="Calendar event not found")
    return event


def _serialize(event: EventModel) -> dict:
    return EventRead.model_validate(event).model_dump(mode="json")


def _record(db: Session, event: EventModel, action: str, details: str = "") -> None:
    db.add(EventHistoryModel(id=str(uuid4()), event_id=event.id, action=action, details=details))


def _queue(db: Session, event: EventModel, operation: str) -> None:
    db.add(EventSyncQueueModel(id=str(uuid4()), event_id=event.id, operation=operation, version=event.version, payload=json.dumps({"id": event.id, "version": event.version, "operation": operation})))


def _event_range(start: datetime, end: datetime):
    return select(EventModel).where(EventModel.deleted_at.is_(None), EventModel.start_at < end, EventModel.end_at > start).order_by(EventModel.start_at)


@router.post("/events", response_model=EventRead, status_code=status.HTTP_201_CREATED)
def create_event(payload: EventCreate, db: Session = Depends(get_db)) -> dict:
    recurrence_id = None
    if payload.recurrence:
        recurrence_id = str(uuid4())
        rule = payload.recurrence
        db.add(RecurringRuleModel(id=recurrence_id, frequency=rule.frequency, interval=rule.interval, weekdays=",".join(str(day) for day in rule.weekdays or []), until=rule.until, timezone=payload.timezone))
    fields = payload.model_dump(exclude={"recurrence"})
    event = EventModel(id=str(uuid4()), recurrence_rule_id=recurrence_id, recurring=bool(payload.recurrence), **fields)
    db.add(event)
    db.flush()
    _record(db, event, "created")
    _queue(db, event, "create")
    db.commit()
    return _serialize(_get_event(db, event.id))


@router.get("/events", response_model=list[EventRead])
def list_events(
    start: datetime | None = None,
    end: datetime | None = None,
    search: str | None = None,
    category: str | None = None,
    event_type: str | None = None,
    priority: str | None = None,
    include_archived: bool = False,
    limit: int = Query(default=500, ge=1, le=5000),
    db: Session = Depends(get_db),
) -> list[dict]:
    statement = select(EventModel).where(EventModel.deleted_at.is_(None))
    if not include_archived:
        statement = statement.where(EventModel.status != EventStatus.ARCHIVED.value)
    if start and end:
        statement = statement.where(EventModel.start_at < end, EventModel.end_at > start)
    if search:
        term = f"%{search.strip()}%"
        statement = statement.where(or_(EventModel.title.ilike(term), EventModel.description.ilike(term), EventModel.location.ilike(term)))
    if category:
        statement = statement.where(EventModel.category == category)
    if event_type:
        statement = statement.where(EventModel.event_type == event_type)
    if priority:
        statement = statement.where(EventModel.priority == priority)
    statement = statement.order_by(EventModel.start_at).limit(limit)
    return [_serialize(event) for event in db.scalars(statement).all()]


@router.get("/today", response_model=list[EventRead])
def today_events(db: Session = Depends(get_db)) -> list[dict]:
    now = _now()
    start = datetime.combine(now.date(), time.min, tzinfo=UTC)
    return [_serialize(event) for event in db.scalars(_event_range(start, start + timedelta(days=1))).all()]


@router.get("/week", response_model=list[EventRead])
def week_events(anchor: datetime | None = None, db: Session = Depends(get_db)) -> list[dict]:
    current = _aware(anchor or _now())
    start = current - timedelta(days=current.weekday())
    start = datetime.combine(start.date(), time.min, tzinfo=current.tzinfo)
    return [_serialize(event) for event in db.scalars(_event_range(start, start + timedelta(days=7))).all()]


@router.get("/month", response_model=list[EventRead])
def month_events(anchor: datetime | None = None, db: Session = Depends(get_db)) -> list[dict]:
    current = _aware(anchor or _now())
    start = datetime(current.year, current.month, 1, tzinfo=current.tzinfo)
    next_month = datetime(current.year + (current.month == 12), 1 if current.month == 12 else current.month + 1, 1, tzinfo=current.tzinfo)
    return [_serialize(event) for event in db.scalars(_event_range(start, next_month)).all()]


@router.get("/agenda", response_model=list[EventRead])
def agenda_events(days: int = Query(default=14, ge=1, le=90), db: Session = Depends(get_db)) -> list[dict]:
    start = _now()
    return [_serialize(event) for event in db.scalars(_event_range(start, start + timedelta(days=days))).all()]


@router.get("/events/{event_id}", response_model=EventRead)
def get_event(event_id: str, db: Session = Depends(get_db)) -> dict:
    return _serialize(_get_event(db, event_id))


@router.put("/events/{event_id}", response_model=EventRead)
def update_event(event_id: str, payload: EventUpdate, db: Session = Depends(get_db)) -> dict:
    event = _get_event(db, event_id)
    changes = payload.model_dump(exclude_unset=True)
    moving = "start_at" in changes or "end_at" in changes
    if moving and event.locked:
        raise HTTPException(status_code=409, detail="Locked events cannot be moved")
    start = _aware(changes.get("start_at", event.start_at))
    end = _aware(changes.get("end_at", event.end_at))
    if end <= start:
        raise HTTPException(status_code=422, detail="end_at must be after start_at")
    if "timezone" in changes:
        from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
        try:
            ZoneInfo(changes["timezone"])
        except ZoneInfoNotFoundError as error:
            raise HTTPException(status_code=422, detail="timezone is not recognized") from error
    for key, value in changes.items():
        setattr(event, key, value)
    event.version += 1
    event.sync_status = "pending"
    _record(db, event, "edited", ",".join(changes.keys()))
    _queue(db, event, "update")
    db.commit()
    return _serialize(_get_event(db, event.id))


@router.delete("/events/{event_id}", response_model=EventRead)
def delete_event(event_id: str, db: Session = Depends(get_db)) -> dict:
    event = _get_event(db, event_id)
    event.deleted_at = _now()
    event.version += 1
    _record(db, event, "deleted")
    _queue(db, event, "delete")
    db.commit()
    return _serialize(event)


@router.post("/events/{event_id}/duplicate", response_model=EventRead, status_code=status.HTTP_201_CREATED)
def duplicate_event(event_id: str, db: Session = Depends(get_db)) -> dict:
    source = _get_event(db, event_id)
    duplicate = EventModel(
        id=str(uuid4()),
        title=f"{source.title} (copy)",
        description=source.description,
        event_type=source.event_type,
        category=source.category,
        priority=source.priority,
        status=EventStatus.SCHEDULED.value,
        start_at=source.start_at + timedelta(days=1),
        end_at=source.end_at + timedelta(days=1),
        timezone=source.timezone,
        location=source.location,
        color=source.color,
        icon=source.icon,
        task_id=source.task_id,
        project_id=source.project_id,
        goal_id=source.goal_id,
        notes=source.notes,
        estimated_minutes=source.estimated_minutes,
        focus_type=source.focus_type,
        energy_level=source.energy_level,
        travel_buffer_minutes=source.travel_buffer_minutes,
        preparation_buffer_minutes=source.preparation_buffer_minutes,
        cleanup_buffer_minutes=source.cleanup_buffer_minutes,
        flexible=source.flexible,
        all_day=source.all_day,
    )
    db.add(duplicate)
    db.flush()
    _record(db, duplicate, "created", f"duplicated_from:{source.id}")
    _queue(db, duplicate, "create")
    db.commit()
    return _serialize(_get_event(db, duplicate.id))


@router.post("/events/{event_id}/archive", response_model=EventRead)
def archive_event(event_id: str, db: Session = Depends(get_db)) -> dict:
    event = _get_event(db, event_id)
    event.status = EventStatus.ARCHIVED.value
    event.archived_at = _now()
    event.version += 1
    _record(db, event, "archived")
    _queue(db, event, "archive")
    db.commit()
    return _serialize(event)


@router.post("/events/{event_id}/restore", response_model=EventRead)
def restore_event(event_id: str, db: Session = Depends(get_db)) -> dict:
    event = _get_event(db, event_id, include_deleted=True)
    event.status = EventStatus.SCHEDULED.value
    event.deleted_at = None
    event.archived_at = None
    event.version += 1
    _record(db, event, "restored")
    _queue(db, event, "restore")
    db.commit()
    return _serialize(event)


@router.get("/events/{event_id}/history", response_model=list[EventHistoryRead])
def event_history(event_id: str, db: Session = Depends(get_db)) -> list[EventHistoryModel]:
    _get_event(db, event_id, include_deleted=True)
    return list(db.scalars(select(EventHistoryModel).where(EventHistoryModel.event_id == event_id).order_by(EventHistoryModel.created_at.desc())).all())


@router.get("/conflicts", response_model=list[ConflictRead])
def calendar_conflicts(start: datetime | None = None, end: datetime | None = None, db: Session = Depends(get_db)) -> list[dict]:
    start_value = _aware(start or _now())
    end_value = _aware(end or (start_value + timedelta(days=1)))
    events = list(db.scalars(_event_range(start_value, end_value)).all())
    return [conflict.__dict__ for conflict in intelligence_service.detect_conflicts(events)]


@router.post("/schedule", response_model=list[ScheduleSuggestion])
def schedule_tasks(payload: ScheduleRequest, db: Session = Depends(get_db)) -> list[ScheduleSuggestion]:
    tasks_statement = select(TaskModel).where(TaskModel.deleted_at.is_(None))
    if payload.task_ids:
        tasks_statement = tasks_statement.where(TaskModel.id.in_(payload.task_ids))
    tasks = list(db.scalars(tasks_statement).all())
    events = list(db.scalars(_event_range(payload.window_start, payload.window_end)).all())
    recommendations = intelligence_service.schedule(tasks, events, payload.window_start, payload.window_end, payload.energy_level, payload.include_breaks)
    return [ScheduleSuggestion(task_id=item.task_id, start_at=item.start_at, end_at=item.end_at, score=item.score, explanation=item.explanation, break_after_minutes=item.break_after_minutes) for item in recommendations]


@router.get("/statistics", response_model=CalendarStatistics)
def calendar_statistics(db: Session = Depends(get_db)) -> CalendarStatistics:
    now = _now()
    start = datetime.combine(now.date(), time.min, tzinfo=UTC)
    end = start + timedelta(days=1)
    events = list(db.scalars(_event_range(start, end)).all())
    completed = sum(event.completed or event.status == EventStatus.COMPLETED.value for event in events)
    focus_minutes = sum(max(0, int((_aware(event.end_at) - _aware(event.start_at)).total_seconds() / 60)) for event in events if event.event_type in {"focus_block", "deep_work"})
    scheduled = sum(max(0, int((_aware(event.end_at) - _aware(event.start_at)).total_seconds() / 60)) for event in events)
    conflicts = len(intelligence_service.detect_conflicts(events))
    overdue = sum((event.end_at if event.end_at.tzinfo else event.end_at.replace(tzinfo=UTC)) < now and not event.completed for event in events)
    return CalendarStatistics(total_events=len(events), completed_events=completed, focus_minutes=focus_minutes, scheduled_minutes=scheduled, overdue_events=overdue, conflicts=conflicts, free_minutes_today=max(0, 24 * 60 - scheduled))


@router.get("/preferences", response_model=CalendarPreferenceRead)
def get_preferences(db: Session = Depends(get_db)) -> CalendarPreferenceModel:
    preference = db.scalar(select(CalendarPreferenceModel).limit(1))
    if preference is None:
        preference = CalendarPreferenceModel(id=str(uuid4()))
        db.add(preference)
        db.commit()
        db.refresh(preference)
    return preference


@router.put("/preferences", response_model=CalendarPreferenceRead)
def update_preferences(payload: CalendarPreferenceUpdate, db: Session = Depends(get_db)) -> CalendarPreferenceModel:
    preference = db.scalar(select(CalendarPreferenceModel).limit(1))
    if preference is None:
        preference = CalendarPreferenceModel(id=str(uuid4()))
        db.add(preference)
    changes = payload.model_dump(exclude_unset=True)
    for key, value in changes.items():
        setattr(preference, key, value)
    if preference.work_end_minute <= preference.work_start_minute:
        raise HTTPException(status_code=422, detail="work_end_minute must be after work_start_minute")
    db.commit()
    db.refresh(preference)
    return preference
