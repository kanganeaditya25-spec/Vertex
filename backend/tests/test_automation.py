from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_workflow_crud_validation_and_manual_execution() -> None:
    suffix = uuid4().hex[:8]
    payload = {
        "name": f"Complete task follow-up {suffix}",
        "description": "Create a next action locally.",
        "workflow_type": "manual",
        "trigger_type": "manual",
        "actions": [
            {
                "action_type": "create_task",
                "label": "Create next task",
                "parameters": {"title": "Follow up {{event.title}}", "category": "automation"},
                "order": 0,
            }
        ],
    }
    created = client.post("/api/v1/automation/workflows", json=payload)
    assert created.status_code == 201
    workflow = created.json()
    validation = client.post(f"/api/v1/automation/workflows/{workflow['id']}/validate")
    assert validation.status_code == 200
    assert validation.json()["valid"] is True

    run = client.post(f"/api/v1/automation/workflows/{workflow['id']}/run", json={"payload": {"title": "Planning"}})
    assert run.status_code == 200
    assert run.json()["status"] == "success"
    assert run.json()["action_logs"][0]["status"] == "success"

    history = client.get("/api/v1/automation/executions", params={"workflow_id": workflow["id"]})
    assert history.status_code == 200
    assert history.json()[0]["workflow_id"] == workflow["id"]

    replay = client.post(f"/api/v1/automation/executions/{run.json()['id']}/replay", json={"payload": {}, "approval_granted": True})
    assert replay.status_code == 200
    assert replay.json()["replay_of"] == run.json()["id"]


def test_event_trigger_conditions_and_destructive_approval() -> None:
    suffix = uuid4().hex[:8]
    event_workflow = client.post(
        "/api/v1/automation/workflows",
        json={
            "name": f"Task completion automation {suffix}",
            "workflow_type": "event",
            "trigger_type": "task_completed",
            "conditions": [{"field": "priority", "operator": "equals", "value": "high"}],
            "actions": [{"action_type": "send_local_notification", "label": "Notify"}],
        },
    )
    assert event_workflow.status_code == 201
    event_result = client.post("/api/v1/automation/events", json={"event_type": "task_completed", "dedupe_key": f"completion-{suffix}", "payload": {"priority": "high", "title": "Ship"}})
    assert event_result.status_code == 200
    assert event_result.json()[0]["status"] == "success"
    duplicate_event = client.post("/api/v1/automation/events", json={"event_type": "task_completed", "dedupe_key": f"completion-{suffix}", "payload": {"priority": "high"}})
    assert duplicate_event.status_code == 200
    assert duplicate_event.json() == []

    destructive = client.post(
        "/api/v1/automation/workflows",
        json={
            "name": f"Protected archive {suffix}",
            "workflow_type": "manual",
            "trigger_type": "manual",
            "actions": [{"action_type": "delete_task", "label": "Delete task", "parameters": {"task_id": "missing"}}],
        },
    )
    assert destructive.status_code == 201
    pending = client.post(f"/api/v1/automation/workflows/{destructive.json()['id']}/run", json={"payload": {}})
    assert pending.status_code == 200
    assert pending.json()["status"] == "pending_approval"
    assert pending.json()["approval_required"] is True


def test_templates_suggestions_and_automation_stats() -> None:
    templates = client.get("/api/v1/automation/templates")
    assert templates.status_code == 200
    assert len(templates.json()) >= 10
    suggestion = client.post("/api/v1/automation/suggest", json={"prompt": "Every Friday create next week's study plan and schedule it on the calendar."})
    assert suggestion.status_code == 200
    assert suggestion.json()["workflow_type"] == "recurring"
    assert suggestion.json()["actions"]
    stats = client.get("/api/v1/automation/stats")
    assert stats.status_code == 200
    assert stats.json()["workflow_count"] >= 2
