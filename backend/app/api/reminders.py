from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.analytics.metrics import metrics
from app.core.event_bus.bus import DomainEvent, bus
from app.core.notifications.service import center
from app.db.session import get_db
from app.reminders.models import ReminderHistoryModel, ReminderPreferenceModel, ReminderRecordModel
from app.reminders.schemas import (
    BulkReminderAction,
    DueReminder,
    ReminderAction,
    ReminderCreate,
    ReminderGroup,
    ReminderHistoryRead,
    ReminderPreferences,
    ReminderRead,
    ReminderStats,
    ReminderUpdate,
    ReminderEvent,
    RescheduleRequest,
    SmartSuggestion,
    SnoozeRequest,
)
from app.reminders.service import due_decisions, group_key, next_occurrence, priority_score, smart_suggestions

router = APIRouter(prefix="/reminders", tags=["reminders"])


def _now() -> datetime:
    return datetime.now(UTC)


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _normalize_dates(values: dict) -> dict:
    for key, value in list(values.items()):
        if isinstance(value, datetime):
            values[key] = _aware(value)
    return values


def _read(reminder: ReminderRecordModel) -> ReminderRead:
    values = _normalize_dates({column.name: getattr(reminder, column.name) for column in ReminderRecordModel.__table__.columns if column.name != "metadata_json"})
    values["metadata"] = reminder.metadata_json or {}
    return ReminderRead.model_validate(values)


def _history_read(item: ReminderHistoryModel) -> ReminderHistoryRead:
    values = _normalize_dates({column.name: getattr(item, column.name) for column in ReminderHistoryModel.__table__.columns if column.name != "metadata_json"})
    values["metadata"] = item.metadata_json or {}
    return ReminderHistoryRead.model_validate(values)


def _get_or_404(db: Session, reminder_id: str) -> ReminderRecordModel:
    reminder = db.get(ReminderRecordModel, reminder_id)
    if reminder is None:
        raise HTTPException(status_code=404, detail="Reminder not found")
    return reminder


def _preferences(db: Session) -> ReminderPreferenceModel:
    preferences = db.get(ReminderPreferenceModel, "default")
    if preferences is None:
        preferences = ReminderPreferenceModel(id="default")
        db.add(preferences)
        db.commit()
        db.refresh(preferences)
    return preferences


def _record(db: Session, reminder: ReminderRecordModel, action: str, reason: str = "", from_at: datetime | None = None, to_at: datetime | None = None, metadata: dict | None = None) -> None:
    db.add(ReminderHistoryModel(id=f"history-{uuid4().hex}", reminder_id=reminder.id, action=action, reason=reason, from_at=from_at, to_at=to_at, metadata_json=metadata or {}))


def _apply(reminder: ReminderRecordModel, changes: dict) -> None:
    for key, value in changes.items():
        setattr(reminder, "metadata_json" if key == "metadata" else key, value)
    reminder.modified_at = _now()


def _create_from_payload(payload: ReminderCreate) -> ReminderModel:
    values = payload.model_dump()
    values["metadata_json"] = values.pop("metadata")
    trigger_at = values.get("trigger_at")
    if values.get("next_trigger_at") is None:
        values["next_trigger_at"] = trigger_at
    return ReminderRecordModel(id=f"reminder-{uuid4().hex}", **values)


@router.get("", response_model=list[ReminderRead])
def list_reminders(
    search: str = Query(default=""),
    reminder_status: str = Query(default="", alias="status"),
    linked_module: str = "",
    workspace_id: str = "",
    project_id: str = "",
    goal_id: str = "",
    category: str = "",
    priority: int | None = Query(default=None, ge=1, le=5),
    include_hidden: bool = False,
    limit: int = Query(default=100, ge=1, le=10_000),
    db: Session = Depends(get_db),
) -> list[ReminderRead]:
    statement = select(ReminderRecordModel).order_by(ReminderRecordModel.next_trigger_at.asc(), ReminderRecordModel.priority.asc())
    if reminder_status:
        statement = statement.where(ReminderRecordModel.status == reminder_status)
    else:
        statement = statement.where(ReminderRecordModel.status != "archived")
    if linked_module:
        statement = statement.where(ReminderRecordModel.linked_module == linked_module)
    if workspace_id:
        statement = statement.where(ReminderRecordModel.workspace_id == workspace_id)
    if project_id:
        statement = statement.where(ReminderRecordModel.project_id == project_id)
    if goal_id:
        statement = statement.where(ReminderRecordModel.goal_id == goal_id)
    if category:
        statement = statement.where(ReminderRecordModel.category == category)
    if priority is not None:
        statement = statement.where(ReminderRecordModel.priority == priority)
    if not include_hidden:
        statement = statement.where(ReminderRecordModel.hidden.is_(False))
    if search:
        term = f"%{search.casefold()}%"
        statement = statement.where(or_(ReminderRecordModel.title.ilike(term), ReminderRecordModel.description.ilike(term), ReminderRecordModel.category.ilike(term)))
    return [_read(item) for item in db.scalars(statement.limit(limit)).all()]


@router.post("", response_model=ReminderRead, status_code=status.HTTP_201_CREATED)
def create_reminder(payload: ReminderCreate, db: Session = Depends(get_db)) -> ReminderRead:
    reminder = _create_from_payload(payload)
    db.add(reminder)
    _record(db, reminder, "created", "user_create", to_at=reminder.next_trigger_at)
    db.commit()
    db.refresh(reminder)
    bus.publish(DomainEvent("reminder.created", {"reminder_id": reminder.id, "linked_module": reminder.linked_module}))
    metrics.increment("reminder.created")
    return _read(reminder)


@router.get("/due", response_model=list[DueReminder])
def due_reminders(db: Session = Depends(get_db)) -> list[DueReminder]:
    preferences = _preferences(db)
    reminders = db.scalars(select(ReminderRecordModel).where(ReminderRecordModel.status.in_(["scheduled", "triggered"]))).all()
    decisions = due_decisions(reminders, preferences)
    result: list[DueReminder] = []
    for decision in decisions:
        result.append(DueReminder(reminder=_read(decision.reminder), delayed=decision.delayed, delay_reason=decision.delay_reason))
    return result


@router.get("/groups", response_model=list[ReminderGroup])
def grouped_reminders(group_by: str = Query(default="today"), db: Session = Depends(get_db)) -> list[ReminderGroup]:
    reminders = db.scalars(select(ReminderRecordModel).where(ReminderRecordModel.status != "archived").order_by(ReminderRecordModel.next_trigger_at.asc())).all()
    grouped: dict[str, list[ReminderRead]] = {}
    for reminder in reminders:
        grouped.setdefault(group_key(reminder, group_by), []).append(_read(reminder))
    labels = {"today": "Today", "tomorrow": "Tomorrow", "this_week": "This Week", "overdue": "Overdue", "later": "Later", "unassigned": "Unassigned", "unscheduled": "Unscheduled"}
    return [ReminderGroup(key=key, label=labels.get(key, key.replace("_", " ").title()), count=len(items), reminders=items) for key, items in grouped.items()]


@router.get("/stats", response_model=ReminderStats)
def reminder_stats(db: Session = Depends(get_db)) -> ReminderStats:
    reminders = db.scalars(select(ReminderRecordModel)).all()
    total = len(reminders)
    active = sum(item.status in {"scheduled", "triggered"} for item in reminders)
    completed = sum(item.status == "completed" for item in reminders)
    dismissed = sum(item.status in {"dismissed", "skipped"} for item in reminders)
    overdue = sum(item.next_trigger_at is not None and _aware(item.next_trigger_at) < _now() and item.status in {"scheduled", "triggered"} for item in reminders)
    snoozed = sum(item.snoozed_count for item in reminders)
    hours: dict[int, int] = {}
    for item in reminders:
        if item.completed_at:
            hours[item.completed_at.hour] = hours.get(item.completed_at.hour, 0) + 1
    best_hour = max(hours, key=hours.get) if hours else None
    return ReminderStats(total=total, active=active, completed=completed, dismissed=dismissed, overdue=overdue, snooze_rate=(snoozed / total if total else 0), completion_rate=(completed / total if total else 0), missed_rate=(dismissed / total if total else 0), best_reminder_hour=best_hour)


@router.get("/suggestions", response_model=list[SmartSuggestion])
def suggestions(db: Session = Depends(get_db)) -> list[SmartSuggestion]:
    reminders = db.scalars(select(ReminderRecordModel).where(ReminderRecordModel.status.in_(["scheduled", "triggered"]))).all()
    history = db.scalars(select(ReminderHistoryModel).order_by(ReminderHistoryModel.occurred_at.asc())).all()
    by_id: dict[str, list[ReminderHistoryModel]] = {}
    for item in history:
        by_id.setdefault(item.reminder_id, []).append(item)
    return [SmartSuggestion.model_validate(item) for item in smart_suggestions(reminders, by_id)]


@router.get("/preferences", response_model=ReminderPreferences)
def get_preferences(db: Session = Depends(get_db)) -> ReminderPreferences:
    preferences = _preferences(db)
    return ReminderPreferences.model_validate({column.name: getattr(preferences, column.name) for column in ReminderPreferenceModel.__table__.columns if column.name != "metadata_json"} | {"metadata": preferences.metadata_json or {}})


@router.put("/preferences", response_model=ReminderPreferences)
def update_preferences(payload: ReminderPreferences, db: Session = Depends(get_db)) -> ReminderPreferences:
    preferences = _preferences(db)
    values = payload.model_dump()
    values["metadata_json"] = values.pop("metadata")
    for key, value in values.items():
        setattr(preferences, key, value)
    preferences.modified_at = _now()
    db.commit()
    db.refresh(preferences)
    bus.publish(DomainEvent("reminder.preferences_updated", {"quiet_hours_enabled": preferences.quiet_hours_enabled}))
    return ReminderPreferences.model_validate({column.name: getattr(preferences, column.name) for column in ReminderPreferenceModel.__table__.columns if column.name != "metadata_json"} | {"metadata": preferences.metadata_json or {}})


@router.post("/events", status_code=status.HTTP_202_ACCEPTED)
def dispatch_reminder_event(payload: ReminderEvent) -> dict[str, object]:
    bus.publish(DomainEvent(payload.event_name, payload.payload))
    metrics.increment("reminder.event_received")
    return {"accepted": True, "event_name": payload.event_name}


@router.get("/{reminder_id}", response_model=ReminderRead)
def get_reminder(reminder_id: str, db: Session = Depends(get_db)) -> ReminderRead:
    return _read(_get_or_404(db, reminder_id))


@router.get("/{reminder_id}/history", response_model=list[ReminderHistoryRead])
def reminder_history(reminder_id: str, db: Session = Depends(get_db)) -> list[ReminderHistoryRead]:
    _get_or_404(db, reminder_id)
    items = db.scalars(select(ReminderHistoryModel).where(ReminderHistoryModel.reminder_id == reminder_id).order_by(ReminderHistoryModel.occurred_at.desc())).all()
    return [_history_read(item) for item in items]


@router.patch("/{reminder_id}", response_model=ReminderRead)
def update_reminder(reminder_id: str, payload: ReminderUpdate, db: Session = Depends(get_db)) -> ReminderRead:
    reminder = _get_or_404(db, reminder_id)
    changes = payload.model_dump(exclude_unset=True)
    if "metadata" in changes:
        changes["metadata_json"] = changes.pop("metadata")
    old_trigger = reminder.next_trigger_at
    _apply(reminder, changes)
    _record(db, reminder, "rescheduled" if "next_trigger_at" in changes or "trigger_at" in changes else "updated", "user_update", from_at=old_trigger, to_at=reminder.next_trigger_at)
    db.commit()
    db.refresh(reminder)
    bus.publish(DomainEvent("reminder.updated", {"reminder_id": reminder.id, "changes": list(changes)}))
    return _read(reminder)


@router.post("/{reminder_id}/complete", response_model=ReminderRead)
def complete_reminder(reminder_id: str, reason: str = "user_complete", db: Session = Depends(get_db)) -> ReminderRead:
    reminder = _get_or_404(db, reminder_id)
    now = _now()
    next_at = next_occurrence(reminder.next_trigger_at or now, reminder.repeat_rule, now)
    if next_at:
        reminder.status = "scheduled"
        reminder.next_trigger_at = next_at
        action = "completed_recurring"
    else:
        reminder.status = "completed"
        reminder.completed_at = now
        action = "completed"
    reminder.last_triggered_at = reminder.last_triggered_at or now
    _record(db, reminder, action, reason, to_at=next_at)
    db.commit()
    db.refresh(reminder)
    center.push("Reminder completed", reminder.title, payload={"reminder_id": reminder.id, "action": action})
    bus.publish(DomainEvent("reminder.completed", {"reminder_id": reminder.id, "linked_module": reminder.linked_module, "next_trigger_at": next_at.isoformat() if next_at else ""}))
    metrics.increment("reminder.completed")
    return _read(reminder)


@router.post("/{reminder_id}/snooze", response_model=ReminderRead)
def snooze_reminder(reminder_id: str, payload: SnoozeRequest, db: Session = Depends(get_db)) -> ReminderRead:
    reminder = _get_or_404(db, reminder_id)
    old_trigger = reminder.next_trigger_at
    base = old_trigger if old_trigger and _aware(old_trigger) > _now() else _now()
    reminder.next_trigger_at = base + timedelta(minutes=payload.minutes)
    reminder.status = "scheduled"
    reminder.snoozed_count += 1
    _record(db, reminder, "snooze", payload.reason, from_at=old_trigger, to_at=reminder.next_trigger_at, metadata={"minutes": payload.minutes})
    db.commit()
    db.refresh(reminder)
    bus.publish(DomainEvent("reminder.snoozed", {"reminder_id": reminder.id, "minutes": payload.minutes}))
    metrics.increment("reminder.snoozed")
    return _read(reminder)


@router.post("/{reminder_id}/reschedule", response_model=ReminderRead)
def reschedule_reminder(reminder_id: str, payload: RescheduleRequest, db: Session = Depends(get_db)) -> ReminderRead:
    reminder = _get_or_404(db, reminder_id)
    old_trigger = reminder.next_trigger_at
    reminder.trigger_at = payload.trigger_at
    reminder.next_trigger_at = payload.trigger_at
    reminder.status = "scheduled"
    _record(db, reminder, "reschedule", payload.reason, from_at=old_trigger, to_at=payload.trigger_at)
    db.commit()
    db.refresh(reminder)
    bus.publish(DomainEvent("reminder.rescheduled", {"reminder_id": reminder.id, "trigger_at": payload.trigger_at.isoformat()}))
    metrics.increment("reminder.rescheduled")
    return _read(reminder)


@router.post("/{reminder_id}/action", response_model=ReminderRead)
def reminder_action(reminder_id: str, payload: ReminderAction, db: Session = Depends(get_db)) -> ReminderRead:
    reminder = _get_or_404(db, reminder_id)
    if payload.action == "complete":
        return complete_reminder(reminder_id, payload.reason, db)
    if payload.action in {"archive", "delete"}:
        reminder.status = "archived"
    elif payload.action == "dismiss":
        reminder.status = "dismissed"
    elif payload.action == "skip":
        reminder.status = "skipped"
    elif payload.action == "duplicate":
        duplicate = ReminderRecordModel(id=f"reminder-{uuid4().hex}", title=f"{reminder.title} (copy)", description=reminder.description, linked_module=reminder.linked_module, linked_item_id=reminder.linked_item_id, workspace_id=reminder.workspace_id, project_id=reminder.project_id, goal_id=reminder.goal_id, category=reminder.category, priority=reminder.priority, trigger_type=reminder.trigger_type, trigger_at=reminder.trigger_at, next_trigger_at=reminder.next_trigger_at, repeat_rule=reminder.repeat_rule or {}, notification_type=reminder.notification_type, sound=reminder.sound, vibration=reminder.vibration, icon=reminder.icon, color=reminder.color, ai_generated=reminder.ai_generated, status="scheduled", location_context=reminder.location_context, locked=reminder.locked, hidden=reminder.hidden, source_rule=reminder.source_rule, metadata_json=reminder.metadata_json or {})
        db.add(duplicate)
        _record(db, duplicate, "created", "duplicate", to_at=duplicate.next_trigger_at)
        db.commit()
        db.refresh(duplicate)
        return _read(duplicate)
    _record(db, reminder, payload.action, payload.reason)
    db.commit()
    db.refresh(reminder)
    bus.publish(DomainEvent(f"reminder.{payload.action}", {"reminder_id": reminder.id, "linked_module": reminder.linked_module}))
    return _read(reminder)


@router.post("/bulk", response_model=list[ReminderRead])
def bulk_action(payload: BulkReminderAction, db: Session = Depends(get_db)) -> list[ReminderRead]:
    reminders = db.scalars(select(ReminderRecordModel).where(ReminderRecordModel.id.in_(payload.reminder_ids))).all()
    found = {item.id for item in reminders}
    missing = set(payload.reminder_ids) - found
    if missing:
        raise HTTPException(status_code=404, detail=f"Reminders not found: {sorted(missing)}")
    now = _now()
    for reminder in reminders:
        if payload.action == "complete":
            reminder.status = "completed"
            reminder.completed_at = now
        elif payload.action == "snooze":
            minutes = payload.snooze_minutes or 15
            reminder.next_trigger_at = now + timedelta(minutes=minutes)
            reminder.status = "scheduled"
            reminder.snoozed_count += 1
        elif payload.action in {"archive", "delete"}:
            reminder.status = "archived"
        elif payload.action == "skip":
            reminder.status = "skipped"
        _record(db, reminder, payload.action, payload.reason)
    db.commit()
    for reminder in reminders:
        db.refresh(reminder)
    bus.publish(DomainEvent("reminder.bulk_action", {"action": payload.action, "count": len(reminders)}))
    metrics.increment(f"reminder.bulk.{payload.action}", len(reminders))
    return [_read(item) for item in reminders]
