from __future__ import annotations

from collections import Counter
from datetime import UTC, datetime, timedelta
from typing import Iterable

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.calendar.models import EventModel
from app.models.task import TaskModel
from app.notes.models import NoteModel
from app.organization.models import Goal, Project
from app.analytics.models import FocusSession
from app.analytics.schemas import AnalyticsDashboard, AnalyticsFilters, BreakdownItem, MetricPoint

COLORS = ["#4F46E5", "#0F766E", "#B45309", "#BE123C", "#0369A1", "#6D28D9"]


def _naive(value: datetime) -> datetime:
    return value.replace(tzinfo=None) if value.tzinfo else value


def _range(filters: AnalyticsFilters) -> tuple[datetime, datetime]:
    end = _naive(filters.end or datetime.now(UTC))
    if filters.start:
        return _naive(filters.start), end
    days = {"daily": 1, "weekly": 7, "monthly": 30, "yearly": 365}[filters.period]
    return end - timedelta(days=days), end


def _clamp(value: float) -> float:
    return round(max(0.0, min(100.0, value)), 1)


def _average(values: Iterable[float]) -> float:
    items = list(values)
    return round(sum(items) / len(items), 1) if items else 0.0


def _breakdown(counter: Counter[str], total: int) -> list[BreakdownItem]:
    return [BreakdownItem(label=label, value=value, percentage=round(value / total * 100, 1) if total else 0, color=COLORS[index % len(COLORS)]) for index, (label, value) in enumerate(counter.most_common())]


def _within(value: datetime | None, start: datetime, end: datetime) -> bool:
    if value is None:
        return False
    normalized = _naive(value)
    return start <= normalized <= end


def build_dashboard(db: Session, filters: AnalyticsFilters) -> AnalyticsDashboard:
    start, end = _range(filters)
    tasks = [item for item in db.scalars(select(TaskModel)).all() if not item.deleted_at and _within(item.created_at, start, end)]
    all_tasks = [item for item in db.scalars(select(TaskModel)).all() if not item.deleted_at]
    events = [item for item in db.scalars(select(EventModel)).all() if _naive(item.end_at) >= start and _naive(item.start_at) <= end and not item.deleted_at]
    notes = [item for item in db.scalars(select(NoteModel)).all() if not item.deleted and not item.archived and _within(item.created_at, start, end)]
    projects = [item for item in db.scalars(select(Project)).all() if not item.archived and (not filters.workspace_id or item.workspace_id == filters.workspace_id) and (not filters.project_id or item.id == filters.project_id)]
    goals = [item for item in db.scalars(select(Goal)).all() if not item.archived and (not filters.workspace_id or item.workspace_id == filters.workspace_id)]
    sessions = [item for item in db.scalars(select(FocusSession)).all() if _within(item.started_at, start, end) and (not filters.project_id or item.project_id == filters.project_id)]

    completed_tasks = [item for item in tasks if item.status == "completed"]
    overdue_tasks = [item for item in all_tasks if item.deadline and _naive(item.deadline) < end and item.status not in {"completed", "cancelled", "archived", "deleted"}]
    completion_rate = _clamp(len(completed_tasks) / len(tasks) * 100 if tasks else 0)
    goal_progress = _average(item.progress for item in goals)
    deep_work_minutes = sum(item.minutes for item in sessions if item.session_type in {"deep_work", "focus", "pomodoro"}) + sum(max(0, item.actual_minutes or item.estimated_minutes) for item in events if item.event_type in {"deep_work", "focus_block"})
    meeting_minutes = sum(max(0, int((_naive(item.end_at) - _naive(item.start_at)).total_seconds() / 60)) for item in events if item.event_type == "meeting")
    learning_minutes = sum(max(0, int((_naive(item.end_at) - _naive(item.start_at)).total_seconds() / 60)) for item in events if item.event_type == "study")
    focus_score = _clamp(deep_work_minutes / max(1, (end - start).days * 60) * 100)
    consistency = _consistency(tasks, start, end)
    time_management = _clamp(100 - (meeting_minutes / max(1, (end - start).days * 8 * 60) * 100))
    productivity_score = _clamp(completion_rate * 0.30 + focus_score * 0.20 + goal_progress * 0.20 + consistency * 0.15 + time_management * 0.15)
    knowledge_growth = _clamp(_average(item.knowledge_score for item in notes))
    average_session = _average(item.minutes for item in sessions if item.minutes > 0)
    daily_series = _daily_series(tasks, events, sessions, start, end)
    recommendations = _recommendations(completion_rate, overdue_tasks, focus_score, goal_progress, consistency, meeting_minutes, deep_work_minutes)
    score_explanation = "Productivity score = 30% task completion + 20% focus time + 20% goal progress + 15% consistency + 15% time management. All values are calculated from local records in the selected range."
    weekly_summary = f"{len(completed_tasks)} of {len(tasks)} tasks completed, {deep_work_minutes} focus minutes, and {len(overdue_tasks)} overdue tasks in this range."
    monthly_summary = f"The workspace contains {len(projects)} active projects, {len(goals)} tracked goals, and {len(notes)} notes created in the selected range."
    return AnalyticsDashboard(period=filters.period, range_start=start, range_end=end, productivity_score=productivity_score, focus_score=focus_score, completion_rate=completion_rate, goal_progress=goal_progress, active_projects=sum(item.status == "active" for item in projects), total_tasks=len(tasks), completed_tasks=len(completed_tasks), overdue_tasks=len(overdue_tasks), deep_work_minutes=deep_work_minutes, meeting_minutes=meeting_minutes, learning_minutes=learning_minutes, notes_created=len(notes), knowledge_growth=knowledge_growth, focus_sessions=len(sessions), average_session_minutes=average_session, weekly_summary=weekly_summary, monthly_summary=monthly_summary, score_explanation=score_explanation, recommendations=recommendations, daily_series=daily_series, task_breakdown=_breakdown(Counter(_task_bucket(item, overdue_tasks) for item in tasks), len(tasks)), category_breakdown=_breakdown(Counter(item.category for item in tasks), len(tasks)), focus_breakdown=_breakdown(Counter(item.event_type for item in events if item.event_type in {"deep_work", "focus_block", "meeting", "study", "break"}), len(events)))


def _task_bucket(item: TaskModel, overdue: list[TaskModel]) -> str:
    if item.status == "completed":
        return "completed"
    if item.status == "blocked":
        return "blocked"
    if any(value.id == item.id for value in overdue):
        return "overdue"
    return "open"


def _consistency(tasks: list[TaskModel], start: datetime, end: datetime) -> float:
    total_days = max(1, (end.date() - start.date()).days + 1)
    active_days = {_naive(item.created_at).date() for item in tasks if item.created_at}
    return _clamp(len(active_days) / total_days * 100)


def _daily_series(tasks: list[TaskModel], events: list[EventModel], sessions: list[FocusSession], start: datetime, end: datetime) -> list[MetricPoint]:
    days = max(1, min(31, (end.date() - start.date()).days + 1))
    points: list[MetricPoint] = []
    for offset in range(days):
        day = start.date() + timedelta(days=offset)
        completed = sum(_naive(item.updated_at).date() == day and item.status == "completed" for item in tasks if item.updated_at)
        focus = sum(item.minutes for item in sessions if _naive(item.started_at).date() == day)
        event_focus = sum(max(0, int((_naive(item.end_at) - _naive(item.start_at)).total_seconds() / 60)) for item in events if _naive(item.start_at).date() == day and item.event_type in {"deep_work", "focus_block"})
        points.append(MetricPoint(label=day.strftime("%b %d"), value=float(completed), secondary_value=float(focus + event_focus)))
    return points


def _recommendations(completion: float, overdue: list[TaskModel], focus: float, goals: float, consistency: float, meetings: int, deep_work: int) -> list[str]:
    recommendations: list[str] = []
    if overdue:
        recommendations.append(f"Review {len(overdue)} overdue task(s) and choose one recovery action before adding new work.")
    if completion < 50:
        recommendations.append("Reduce active work in progress and define a smaller daily finish line.")
    if focus < 35:
        recommendations.append("Protect one uninterrupted focus block; the current range has limited deep-work time.")
    if goals < 50:
        recommendations.append("Link the next task to a goal so daily execution contributes to a visible outcome.")
    if consistency < 50:
        recommendations.append("Use a short daily planning ritual to create a more consistent work pattern.")
    if meetings > deep_work and meetings > 120:
        recommendations.append("Review meeting density and reserve recovery space around high-context calendar days.")
    if not recommendations:
        recommendations.append("Keep the current rhythm and review the next milestone before the next planning cycle.")
    return recommendations[:5]
