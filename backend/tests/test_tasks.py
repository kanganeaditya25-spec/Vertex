from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_task_lifecycle_and_explanation() -> None:
    title = f"Module 3 test {uuid4()}"
    created = client.post(
        "/api/v1/tasks",
        json={
            "title": title,
            "description": "Validate the smart task lifecycle",
            "priority": "urgent",
            "deadline": (datetime.now(UTC) + timedelta(hours=18)).isoformat(),
            "estimated_minutes": 90,
            "tags": ["module3", "testing"],
            "checklist": [{"text": "Create"}, {"text": "Complete"}],
        },
    )
    assert created.status_code == 201
    task = created.json()
    task_id = task["id"]
    assert task["title"] == title
    assert task["ai_score"] > 0
    assert "because" in task["explanation"]
    assert len(task["tags"]) == 2
    assert len(task["checklist"]) == 2

    completed = client.post(f"/api/v1/tasks/{task_id}/complete")
    assert completed.status_code == 200
    assert completed.json()["status"] == "completed"
    assert completed.json()["completion_percent"] == 100

    history = client.get(f"/api/v1/tasks/{task_id}/history")
    assert history.status_code == 200
    assert {item["action"] for item in history.json()} >= {"created", "completed"}

    duplicate = client.post(f"/api/v1/tasks/{task_id}/duplicate")
    assert duplicate.status_code == 201
    assert duplicate.json()["title"].endswith("(copy)")

    client.delete(f"/api/v1/tasks/{task_id}")
    client.delete(f"/api/v1/tasks/{duplicate.json()['id']}")


def test_task_statistics_contract() -> None:
    response = client.get("/api/v1/tasks/statistics")
    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"total", "completed", "remaining", "overdue", "estimated_minutes", "urgent", "completion_percent"}
