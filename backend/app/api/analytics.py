from __future__ import annotations

import csv
import io
from datetime import datetime
from typing import Any, Literal

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.analytics.engine import build_dashboard
from app.analytics.models import AnalyticsDashboardLayout, AnalyticsSnapshot, FocusSession
from app.analytics.schemas import AnalyticsDashboard, AnalyticsFilters, AnalyticsInsight, AnalyticsLayoutCreate, AnalyticsLayoutRead, AnalyticsReport, FocusSessionCreate, FocusSessionRead
from app.db.session import get_db

router = APIRouter(prefix="/analytics", tags=["analytics"])

DEFAULT_WIDGETS = [
    {"id": "productivity_score", "label": "Productivity score", "visible": True, "order": 0},
    {"id": "focus_score", "label": "Focus score", "visible": True, "order": 1},
    {"id": "completion_rate", "label": "Completion rate", "visible": True, "order": 2},
    {"id": "goal_progress", "label": "Goal progress", "visible": True, "order": 3},
    {"id": "weekly_summary", "label": "Weekly summary", "visible": True, "order": 4},
    {"id": "task_breakdown", "label": "Task breakdown", "visible": True, "order": 5},
    {"id": "focus_trend", "label": "Focus trend", "visible": True, "order": 6},
    {"id": "recommendations", "label": "AI recommendations", "visible": True, "order": 7},
]


def _filters(period: str, start: datetime | None, end: datetime | None, workspace_id: str | None, project_id: str | None, goal_id: str | None) -> AnalyticsFilters:
    return AnalyticsFilters(period=period, start=start, end=end, workspace_id=workspace_id, project_id=project_id, goal_id=goal_id)


def _dashboard(db: Session, period: str, start: datetime | None, end: datetime | None, workspace_id: str | None, project_id: str | None, goal_id: str | None) -> AnalyticsDashboard:
    return build_dashboard(db, _filters(period, start, end, workspace_id, project_id, goal_id))


@router.get("/dashboard", response_model=AnalyticsDashboard)
def analytics_dashboard(period: str = Query(default="weekly", pattern="^(daily|weekly|monthly|yearly)$"), start: datetime | None = None, end: datetime | None = None, workspace_id: str | None = None, project_id: str | None = None, goal_id: str | None = None, db: Session = Depends(get_db)) -> AnalyticsDashboard:
    dashboard = _dashboard(db, period, start, end, workspace_id, project_id, goal_id)
    db.add(AnalyticsSnapshot(period=dashboard.period, range_start=dashboard.range_start, range_end=dashboard.range_end, metrics=dashboard.model_dump(mode="json")))
    db.commit()
    return dashboard


@router.get("/insights", response_model=list[AnalyticsInsight])
def analytics_insights(period: str = Query(default="weekly", pattern="^(daily|weekly|monthly|yearly)$"), workspace_id: str | None = None, project_id: str | None = None, db: Session = Depends(get_db)) -> list[AnalyticsInsight]:
    dashboard = _dashboard(db, period, None, None, workspace_id, project_id, None)
    insights: list[AnalyticsInsight] = [AnalyticsInsight(kind="explanation", title="How your score works", body=dashboard.score_explanation, confidence=1.0, metric="productivity_score")]
    for index, recommendation in enumerate(dashboard.recommendations):
        kind = "warning" if any(word in recommendation.casefold() for word in ("overdue", "limited", "reduce", "review meeting")) else "recommendation"
        insights.append(AnalyticsInsight(kind=kind, title=f"Local insight {index + 1}", body=recommendation, confidence=0.82, metric=None))
    if dashboard.productivity_score >= 75:
        insights.append(AnalyticsInsight(kind="positive", title="Strong productivity rhythm", body="Your completion, focus, and consistency signals are currently above the healthy baseline for this range.", confidence=0.78, metric="productivity_score"))
    return insights


@router.post("/focus-sessions", response_model=FocusSessionRead, status_code=status.HTTP_201_CREATED)
def create_focus_session(payload: FocusSessionCreate, db: Session = Depends(get_db)) -> FocusSession:
    session = FocusSession(**payload.model_dump())
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


@router.get("/focus-sessions", response_model=list[FocusSessionRead])
def list_focus_sessions(limit: int = Query(default=100, ge=1, le=1000), db: Session = Depends(get_db)) -> list[FocusSession]:
    return list(db.scalars(select(FocusSession).order_by(FocusSession.started_at.desc()).limit(limit)).all())


@router.get("/reports/{period}", response_model=AnalyticsReport)
def analytics_report(period: Literal["daily", "weekly", "monthly", "yearly"], workspace_id: str | None = None, db: Session = Depends(get_db)) -> AnalyticsReport:
    dashboard = _dashboard(db, period, None, None, workspace_id, None, None)
    return AnalyticsReport(title=f"FocusFlow {period.title()} Productivity Report", period=period, generated_at=datetime.now(), sections=[{"title": "Score", "content": dashboard.score_explanation, "productivity_score": dashboard.productivity_score, "focus_score": dashboard.focus_score}, {"title": "Work completed", "content": dashboard.weekly_summary, "task_breakdown": [item.model_dump() for item in dashboard.task_breakdown]}, {"title": "Recommendations", "content": "Review these local, explainable recommendations before changing your plan.", "items": dashboard.recommendations}])


@router.get("/reports/{period}/csv")
def analytics_csv(period: Literal["daily", "weekly", "monthly", "yearly"], workspace_id: str | None = None, db: Session = Depends(get_db)) -> Response:
    dashboard = _dashboard(db, period, None, None, workspace_id, None, None)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["metric", "value"])
    for key, value in (("productivity_score", dashboard.productivity_score), ("focus_score", dashboard.focus_score), ("completion_rate", dashboard.completion_rate), ("goal_progress", dashboard.goal_progress), ("active_projects", dashboard.active_projects), ("total_tasks", dashboard.total_tasks), ("completed_tasks", dashboard.completed_tasks), ("overdue_tasks", dashboard.overdue_tasks), ("deep_work_minutes", dashboard.deep_work_minutes), ("meeting_minutes", dashboard.meeting_minutes), ("learning_minutes", dashboard.learning_minutes), ("notes_created", dashboard.notes_created), ("knowledge_growth", dashboard.knowledge_growth)):
        writer.writerow([key, value])
    return Response(content=output.getvalue(), media_type="text/csv", headers={"Content-Disposition": f"attachment; filename=focusflow-{period}-report.csv"})


@router.get("/layouts", response_model=list[AnalyticsLayoutRead])
def list_layouts(db: Session = Depends(get_db)) -> list[AnalyticsDashboardLayout]:
    layouts = list(db.scalars(select(AnalyticsDashboardLayout).order_by(AnalyticsDashboardLayout.updated_at.desc())).all())
    if not layouts:
        default = AnalyticsDashboardLayout(name="Default analytics", widgets=DEFAULT_WIDGETS)
        db.add(default)
        db.commit()
        db.refresh(default)
        return [default]
    return layouts


@router.post("/layouts", response_model=AnalyticsLayoutRead, status_code=status.HTTP_201_CREATED)
def create_layout(payload: AnalyticsLayoutCreate, db: Session = Depends(get_db)) -> AnalyticsDashboardLayout:
    layout = AnalyticsDashboardLayout(**payload.model_dump())
    db.add(layout)
    db.commit()
    db.refresh(layout)
    return layout


@router.patch("/layouts/{layout_id}", response_model=AnalyticsLayoutRead)
def update_layout(layout_id: str, payload: AnalyticsLayoutCreate, db: Session = Depends(get_db)) -> AnalyticsDashboardLayout:
    layout = db.get(AnalyticsDashboardLayout, layout_id)
    if layout is None:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Analytics layout not found")
    layout.name = payload.name
    layout.widgets = payload.widgets
    db.commit()
    db.refresh(layout)
    return layout


@router.get("/snapshots", response_model=list[dict[str, Any]])
def list_snapshots(limit: int = Query(default=30, ge=1, le=200), db: Session = Depends(get_db)) -> list[dict[str, Any]]:
    snapshots = list(db.scalars(select(AnalyticsSnapshot).order_by(AnalyticsSnapshot.created_at.desc()).limit(limit)).all())
    return [{"id": item.id, "period": item.period, "range_start": item.range_start, "range_end": item.range_end, "metrics": item.metrics, "created_at": item.created_at} for item in snapshots]
