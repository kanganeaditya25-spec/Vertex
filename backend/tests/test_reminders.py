from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _create(title: str, trigger_at: datetime, **extra: object) -> dict:
    payload = {"title": title, "trigger_at": trigger_at.isoformat(), "next_trigger_at": trigger_at.isoformat(), **extra}
    response = client.post("/api/v1/reminders", json=payload)
    assert response.status_code == 201, response.text
    return response.json()


def test_reminder_crud_snooze_history_and_search() -> None:
    now = datetime.now(UTC)
    reminder = _create("Review project brief", now + timedelta(minutes=5), linked_module="projects", priority=2, category="review")
    reminder_id = reminder["id"]

    listed = client.get("/api/v1/reminders", params={"search": "project brief"})
    assert listed.status_code == 200
    assert any(item["id"] == reminder_id for item in listed.json())

    snoozed = client.post(f"/api/v1/reminders/{reminder_id}/snooze", json={"minutes": 15})
    assert snoozed.status_code == 200
    assert snoozed.json()["snoozed_count"] == 1

    history = client.get(f"/api/v1/reminders/{reminder_id}/history")
    assert history.status_code == 200
    assert any(item["action"] == "snooze" for item in history.json())

    completed = client.post(f"/api/v1/reminders/{reminder_id}/complete")
    assert completed.status_code == 200
    assert completed.json()["status"] == "completed"


def test_recurring_completion_schedules_next_occurrence() -> None:
    trigger_at = datetime.now(UTC) - timedelta(days=1)
    reminder = _create("Daily reflection", trigger_at, repeat_rule={"kind": "daily"}, linked_module="notes")

    completed = client.post(f"/api/v1/reminders/{reminder['id']}/complete")
    assert completed.status_code == 200
    data = completed.json()
    assert data["status"] == "scheduled"
    assert data["next_trigger_at"] is not None
    assert datetime.fromisoformat(data["next_trigger_at"]) > trigger_at


def test_due_grouping_quiet_hours_bulk_and_stats() -> None:
    due = _create("Quiet-hour review", datetime.now(UTC) - timedelta(minutes=2), priority=3)
    preferences = client.put("/api/v1/reminders/preferences", json={"quiet_hours_enabled": True, "quiet_start_minutes": 0, "quiet_end_minutes": 1439})
    assert preferences.status_code == 200

    due_response = client.get("/api/v1/reminders/due")
    assert due_response.status_code == 200
    match = next(item for item in due_response.json() if item["reminder"]["id"] == due["id"])
    assert match["delayed"] is True
    assert match["delay_reason"] == "quiet_hours"

    groups = client.get("/api/v1/reminders/groups", params={"group_by": "priority"})
    assert groups.status_code == 200
    assert any(group["count"] >= 1 for group in groups.json())

    bulk = client.post("/api/v1/reminders/bulk", json={"reminder_ids": [due["id"]], "action": "archive"})
    assert bulk.status_code == 200
    assert bulk.json()[0]["status"] == "archived"

    stats = client.get("/api/v1/reminders/stats")
    assert stats.status_code == 200
    assert "completion_rate" in stats.json()


def test_event_bus_creates_follow_up_reminders() -> None:
    event = client.post("/api/v1/reminders/events", json={"event_name": "automation.workflow", "payload": {"create_reminder": True, "title": "Automation follow-up", "entity_id": "workflow-1", "after_minutes": 30}})
    assert event.status_code == 202

    reminders = client.get("/api/v1/reminders", params={"search": "Automation follow-up"})
    assert reminders.status_code == 200
    assert any(item["source_rule"] == "automation_workflow" for item in reminders.json())
