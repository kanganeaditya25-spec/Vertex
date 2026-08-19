from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

from sqlalchemy.orm import sessionmaker

from app.core.event_bus.bus import DomainEvent
from app.core.notifications.service import center
from app.reminders.models import ReminderRecordModel, ReminderHistoryModel


def attach_reminder_event_handlers(event_bus: object, session_factory: sessionmaker) -> None:
    def on_domain_event(event: DomainEvent) -> None:
        payload = event.payload
        if event.name == "task.completed" and payload.get("create_review_reminder"):
            _create_event_reminder(session_factory, "Study Review", "tasks", payload, int(payload.get("review_after_minutes", 24 * 60)), "task_completed_review")
        elif event.name == "project.started" and payload.get("create_reminder"):
            _create_event_reminder(session_factory, str(payload.get("title", "Project review")), "projects", payload, int(payload.get("after_minutes", 60)), "project_started")
        elif event.name == "asset.processed" and payload.get("create_review_reminder"):
            _create_event_reminder(session_factory, "Document Review", "assets", payload, int(payload.get("review_after_minutes", 7 * 24 * 60)), "asset_review")
        elif event.name == "automation.workflow" and payload.get("create_reminder"):
            _create_event_reminder(session_factory, str(payload.get("title", "Automation follow-up")), "automation", payload, int(payload.get("after_minutes", 30)), "automation_workflow")

    for event_name in ("task.completed", "project.started", "asset.processed", "automation.workflow"):
        event_bus.subscribe(event_name, on_domain_event)


def _create_event_reminder(session_factory: sessionmaker, title: str, module: str, payload: dict[str, Any], after_minutes: int, source_rule: str) -> None:
    now = datetime.now(UTC)
    reminder_id = f"reminder-{uuid4().hex}"
    linked_item_id = str(payload.get("task_id") or payload.get("project_id") or payload.get("asset_id") or payload.get("entity_id") or "")
    reminder = ReminderRecordModel(id=reminder_id, title=title, description=str(payload.get("description", "Created from a workspace event.")), linked_module=module, linked_item_id=linked_item_id, workspace_id=str(payload.get("workspace_id", "")), project_id=str(payload.get("project_id", "")), goal_id=str(payload.get("goal_id", "")), category="review", priority=int(payload.get("priority", 3)), trigger_type="event_based", trigger_at=now + timedelta(minutes=after_minutes), next_trigger_at=now + timedelta(minutes=after_minutes), repeat_rule={}, notification_type="local", ai_generated=False, source_rule=source_rule, metadata_json={"event_payload": payload})
    db = session_factory()
    try:
        db.add(reminder)
        db.add(ReminderHistoryModel(id=f"history-{uuid4().hex}", reminder_id=reminder_id, action="created", reason=source_rule, to_at=reminder.next_trigger_at, metadata_json={"event": source_rule}))
        db.commit()
        center.push("Follow-up reminder scheduled", title, payload={"reminder_id": reminder_id, "source_rule": source_rule})
    finally:
        db.close()
