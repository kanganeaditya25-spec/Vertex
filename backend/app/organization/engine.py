from __future__ import annotations

from datetime import date
from typing import Iterable

from app.organization.models import Goal, Milestone, Project, Workspace


def _average(values: Iterable[float]) -> float:
    items = list(values)
    return round(sum(items) / len(items), 1) if items else 0.0


def effective_project_progress(project: Project, milestones: Iterable[Milestone]) -> float:
    milestone_items = list(milestones)
    if milestone_items:
        return _average(milestone.progress for milestone in milestone_items)
    return round(project.progress, 1)


def deadline_risk(project: Project, milestones: Iterable[Milestone], today: date | None = None) -> str:
    if project.status in {"completed", "cancelled", "archived"} or project.progress >= 100:
        return "none"
    deadline = project.deadline
    milestone_dates = [item.deadline for item in milestones if item.deadline is not None and not item.completed]
    if deadline is None and milestone_dates:
        deadline = min(milestone_dates)
    if deadline is None:
        return "none"
    current = today or date.today()
    days_left = (deadline - current).days
    progress = project.progress
    if days_left < 0:
        return "high"
    if days_left <= 3 and progress < 80:
        return "high"
    if days_left <= 14 and progress < 60:
        return "medium"
    if days_left <= 30 and progress < 40:
        return "medium"
    return "low" if days_left <= 30 else "none"


def project_recommendations(project: Project, milestones: Iterable[Milestone], goals: Iterable[Goal]) -> list[str]:
    items = list(milestones)
    recommendations: list[str] = []
    risk = deadline_risk(project, items)
    if risk == "high":
        recommendations.append("Protect a focused work block and review the critical path today.")
    elif risk == "medium":
        recommendations.append("Break the next milestone into smaller tasks and schedule a review before the deadline.")
    if not items:
        recommendations.append("Add milestones so project progress and dependency risk can be measured.")
    elif any(item.dependency_ids for item in items):
        recommendations.append("Review milestone dependencies before starting work on blocked items.")
    if project.progress == 0 and project.status == "active":
        recommendations.append("Choose one concrete first task to move the project out of zero progress.")
    if list(goals):
        recommendations.append("Keep the next action connected to the linked goal with the highest priority.")
    return recommendations[:4]


def project_summary(project: Project, milestones: Iterable[Milestone], goals: Iterable[Goal]) -> str:
    risk = deadline_risk(project, milestones)
    goal_count = len(list(goals))
    if risk == "high":
        return f"{project.name} needs attention: it has a high deadline risk at {project.progress:.0f}% progress."
    if risk == "medium":
        return f"{project.name} is moving at {project.progress:.0f}% with a medium deadline risk."
    if goal_count:
        return f"{project.name} is {project.progress:.0f}% complete and aligned with {goal_count} goal(s)."
    return f"{project.name} is {project.progress:.0f}% complete."


def search_score(query: str, *fields: str) -> float:
    needle = query.casefold().strip()
    if not needle:
        return 0.0
    score = 0.0
    for index, field in enumerate(fields):
        value = field.casefold()
        if needle == value:
            score += 1.0 - index * 0.05
        elif needle in value:
            score += 0.7 - index * 0.05
        for token in needle.split():
            if token and token in value:
                score += 0.1
    return round(min(score, 1.0), 3)


def workspace_is_archived(workspace: Workspace) -> bool:
    return workspace.archived


def dependency_conflicts(milestones: Iterable[Milestone]) -> list[dict[str, str]]:
    items = list(milestones)
    by_id = {item.id: item for item in items}
    conflicts: list[dict[str, str]] = []
    graph = {item.id: list(item.dependency_ids or []) for item in items}
    for item in items:
        for dependency_id in graph[item.id]:
            if dependency_id == item.id:
                conflicts.append({"milestone_id": item.id, "milestone_name": item.name, "dependency_id": dependency_id, "conflict_type": "self", "explanation": "A milestone cannot depend on itself."})
            elif dependency_id not in by_id:
                conflicts.append({"milestone_id": item.id, "milestone_name": item.name, "dependency_id": dependency_id, "conflict_type": "missing", "explanation": "The dependency ID does not belong to a milestone in this project."})
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str, path: list[str]) -> None:
        if node in visiting:
            cycle_start = path.index(node) if node in path else 0
            for cycle_node in path[cycle_start:]:
                current = by_id[cycle_node]
                conflicts.append({"milestone_id": current.id, "milestone_name": current.name, "dependency_id": node, "conflict_type": "cycle", "explanation": "Milestone dependencies contain a cycle, so the critical path cannot be ordered."})
            return
        if node in visited or node not in graph:
            return
        visiting.add(node)
        for dependency in graph[node]:
            if dependency in graph:
                visit(dependency, [*path, dependency])
        visiting.remove(node)
        visited.add(node)

    for item in items:
        visit(item.id, [item.id])
    unique: dict[tuple[str, str, str], dict[str, str]] = {}
    for conflict in conflicts:
        unique[(conflict["milestone_id"], conflict["dependency_id"], conflict["conflict_type"])] = conflict
    return list(unique.values())


def project_manager_plan(project: Project, milestones: Iterable[Milestone], goals: Iterable[Goal], task_count: int, conflict_count: int) -> dict[str, object]:
    items = list(milestones)
    goal_items = list(goals)
    incomplete = [item.name for item in items if not item.completed]
    suggested = incomplete[:3] or ["Define the first milestone", "Create the first linked task", "Schedule a review checkpoint"]
    estimated = project.estimated_minutes or max(120, len(suggested) * 180)
    suggested_deadline = project.deadline or (date.today() if project.progress >= 100 else date.today())
    blockers = []
    if conflict_count:
        blockers.append(f"Resolve {conflict_count} dependency conflict(s) before trusting the critical path.")
    if project.status in {"waiting", "on_hold", "blocked"}:
        blockers.append(f"Project status is {project.status.replace('_', ' ')}; identify the unblock decision.")
    if not task_count:
        blockers.append("No linked tasks exist yet; create one concrete next action.")
    next_actions = [f"Advance milestone: {name}" for name in suggested]
    if goal_items:
        next_actions.append("Keep the next task linked to the highest-priority goal.")
    return {"summary": project_summary(project, items, goal_items), "estimated_minutes": estimated, "suggested_deadline": suggested_deadline, "milestones": suggested, "next_actions": next_actions[:4], "blockers": blockers, "explanation": "This plan is generated locally from project status, progress, deadlines, milestones, dependencies, linked goals, and linked task count. It is deterministic and does not call a cloud model."}
