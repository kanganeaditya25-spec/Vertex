from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_calendar_event_lifecycle_and_conflict_detection() -> None:
    base = datetime.now(UTC).replace(second=0, microsecond=0) + timedelta(days=2)
    first = client.post(
        "/api/v1/calendar/events",
        json={
            "title": f"Planning block {uuid4()}",
            "event_type": "focus_block",
            "priority": "high",
            "start_at": base.isoformat(),
            "end_at": (base + timedelta(minutes=60)).isoformat(),
            "timezone": "UTC",
            "energy_level": "high",
            "flexible": False,
        },
    )
    assert first.status_code == 201
    first_event = first.json()
    assert first_event["event_type"] == "focus_block"

    second = client.post(
        "/api/v1/calendar/events",
        json={
            "title": f"Overlapping meeting {uuid4()}",
            "event_type": "meeting",
            "start_at": (base + timedelta(minutes=30)).isoformat(),
            "end_at": (base + timedelta(minutes=90)).isoformat(),
            "timezone": "UTC",
        },
    )
    assert second.status_code == 201
    second_event = second.json()

    conflicts = client.get(
        "/api/v1/calendar/conflicts",
        params={"start": (base - timedelta(minutes=1)).isoformat(), "end": (base + timedelta(hours=2)).isoformat()},
    )
    assert conflicts.status_code == 200
    assert any(first_event["id"] in item["event_ids"] and second_event["id"] in item["event_ids"] for item in conflicts.json())

    history = client.get(f"/api/v1/calendar/events/{first_event['id']}/history")
    assert history.status_code == 200
    assert history.json()[0]["action"] == "created"

    client.delete(f"/api/v1/calendar/events/{first_event['id']}")
    client.delete(f"/api/v1/calendar/events/{second_event['id']}")


def test_calendar_rejects_invalid_time_and_returns_statistics() -> None:
    base = datetime.now(UTC).replace(second=0, microsecond=0) + timedelta(days=3)
    invalid = client.post(
        "/api/v1/calendar/events",
        json={"title": "Invalid", "start_at": base.isoformat(), "end_at": base.isoformat(), "timezone": "UTC"},
    )
    assert invalid.status_code == 422

    statistics = client.get("/api/v1/calendar/statistics")
    assert statistics.status_code == 200
    assert set(statistics.json()) == {"total_events", "completed_events", "focus_minutes", "scheduled_minutes", "overdue_events", "conflicts", "free_minutes_today"}
