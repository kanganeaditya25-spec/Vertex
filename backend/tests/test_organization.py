from datetime import date, timedelta
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_workspace_project_goal_milestone_lifecycle_and_dashboard() -> None:
    suffix = uuid4().hex[:8]
    workspace = client.post("/api/v1/organization/workspaces", json={"name": f"Module 7 Workspace {suffix}", "favorite": True})
    assert workspace.status_code == 201
    workspace_data = workspace.json()

    goal = client.post("/api/v1/organization/goals", json={"workspace_id": workspace_data["id"], "title": f"Ship organization layer {suffix}", "goal_type": "quarterly", "priority": "high"})
    assert goal.status_code == 201
    goal_data = goal.json()

    project = client.post(
        "/api/v1/organization/projects",
        json={
            "workspace_id": workspace_data["id"],
            "name": f"Workspace architecture {suffix}",
            "status": "active",
            "deadline": (date.today() + timedelta(days=10)).isoformat(),
            "linked_goal_ids": [goal_data["id"]],
        },
    )
    assert project.status_code == 201
    project_data = project.json()

    first = client.post("/api/v1/organization/milestones", json={"project_id": project_data["id"], "name": "Domain model", "progress": 50})
    second = client.post("/api/v1/organization/milestones", json={"project_id": project_data["id"], "name": "Client workspace", "progress": 0})
    assert first.status_code == 201 and second.status_code == 201

    dashboard = client.get(f"/api/v1/organization/projects/{project_data['id']}/dashboard")
    assert dashboard.status_code == 200
    dashboard_data = dashboard.json()
    assert dashboard_data["task_count"] == 0
    assert dashboard_data["average_milestone_progress"] == 25.0
    assert dashboard_data["linked_goals"][0]["id"] == goal_data["id"]
    assert dashboard_data["deadline_risk"] == "medium"

    updated = client.patch(f"/api/v1/organization/milestones/{second.json()['id']}", json={"progress": 100})
    assert updated.status_code == 200 and updated.json()["completed"] is True
    refreshed = client.get(f"/api/v1/organization/projects/{project_data['id']}")
    assert refreshed.json()["progress"] == 75.0

    intelligence = client.get(f"/api/v1/organization/projects/{project_data['id']}/intelligence")
    assert intelligence.status_code == 200
    assert intelligence.json()["confidence"] > 0.7
    assert intelligence.json()["explanation"]

    search = client.get("/api/v1/organization/search", params={"q": "architecture"})
    assert search.status_code == 200
    assert any(item["entity_id"] == project_data["id"] for item in search.json()["results"])

    stats = client.get("/api/v1/organization/statistics")
    assert stats.status_code == 200
    assert stats.json()["project_count"] >= 1

    client.delete(f"/api/v1/organization/projects/{project_data['id']}")
    client.delete(f"/api/v1/organization/goals/{goal_data['id']}")
    client.delete(f"/api/v1/organization/workspaces/{workspace_data['id']}")


def test_templates_instantiate_and_duplicate_workspace() -> None:
    workspace = client.post("/api/v1/organization/workspaces", json={"name": f"Template test {uuid4().hex[:8]}"})
    assert workspace.status_code == 201
    workspace_id = workspace.json()["id"]

    templates = client.get("/api/v1/organization/templates")
    assert templates.status_code == 200
    assert len(templates.json()) >= 7
    template = next(item for item in templates.json() if item["name"] == "Research")

    instantiated = client.post(f"/api/v1/organization/templates/{template['id']}/instantiate", params={"workspace_id": workspace_id})
    assert instantiated.status_code == 201
    assert len(instantiated.json()["milestones"]) == 4

    duplicate = client.post(f"/api/v1/organization/workspaces/{workspace_id}/duplicate")
    assert duplicate.status_code == 201
    assert duplicate.json()["name"].endswith("Copy")

    client.delete(f"/api/v1/organization/projects/{instantiated.json()['project']['id']}")
    client.delete(f"/api/v1/organization/workspaces/{workspace_id}")
    client.delete(f"/api/v1/organization/workspaces/{duplicate.json()['id']}")
