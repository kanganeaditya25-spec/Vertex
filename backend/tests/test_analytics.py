from datetime import UTC, datetime
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_analytics_dashboard_focus_session_insights_and_report() -> None:
    session = client.post(
        "/api/v1/analytics/focus-sessions",
        json={
            "started_at": datetime.now(UTC).isoformat(),
            "minutes": 50,
            "session_type": "deep_work",
            "interruptions": 1,
            "completed": True,
        },
    )
    assert session.status_code == 201
    assert session.json()["minutes"] == 50

    dashboard = client.get("/api/v1/analytics/dashboard", params={"period": "weekly"})
    assert dashboard.status_code == 200
    data = dashboard.json()
    assert data["deep_work_minutes"] >= 50
    assert 0 <= data["productivity_score"] <= 100
    assert "30% task completion" in data["score_explanation"]
    assert isinstance(data["daily_series"], list)

    insights = client.get("/api/v1/analytics/insights", params={"period": "weekly"})
    assert insights.status_code == 200
    assert any(item["kind"] == "explanation" for item in insights.json())

    report = client.get("/api/v1/analytics/reports/weekly")
    assert report.status_code == 200
    assert len(report.json()["sections"]) >= 3

    csv_report = client.get("/api/v1/analytics/reports/weekly/csv")
    assert csv_report.status_code == 200
    assert "productivity_score" in csv_report.text
    assert "text/csv" in csv_report.headers["content-type"]

    snapshots = client.get("/api/v1/analytics/snapshots")
    assert snapshots.status_code == 200
    assert len(snapshots.json()) >= 1


def test_analytics_layouts_are_persisted_and_customizable() -> None:
    default = client.get("/api/v1/analytics/layouts")
    assert default.status_code == 200
    assert default.json()

    layout = client.post("/api/v1/analytics/layouts", json={"name": f"Focus layout {uuid4().hex[:8]}", "widgets": [{"id": "focus_score", "visible": True, "order": 0}]})
    assert layout.status_code == 201
    layout_data = layout.json()
    assert layout_data["widgets"][0]["id"] == "focus_score"

    updated = client.patch(f"/api/v1/analytics/layouts/{layout_data['id']}", json={"name": "Updated focus layout", "widgets": []})
    assert updated.status_code == 200
    assert updated.json()["name"] == "Updated focus layout"
