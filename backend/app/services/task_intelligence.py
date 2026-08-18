from dataclasses import dataclass
from datetime import UTC, datetime

from app.models.task import TaskModel


@dataclass(frozen=True)
class TaskRecommendation:
    priority_score: float
    urgency_score: float
    risk_score: float
    confidence_score: float
    explanation: str


_PRIORITY_WEIGHTS = {
    "critical": 100.0,
    "urgent": 85.0,
    "high": 70.0,
    "medium": 50.0,
    "low": 30.0,
    "someday": 10.0,
}


class TaskIntelligenceService:
    """Transparent, offline-safe scoring used when Ollama is unavailable."""

    def recommend(self, task: TaskModel, now: datetime | None = None) -> TaskRecommendation:
        current = now or datetime.now(UTC)
        urgency = self._urgency(task, current)
        priority_input = _PRIORITY_WEIGHTS.get(task.priority.lower(), 50.0)
        effort_penalty = min(task.estimated_minutes / 240, 20.0)
        score = max(0.0, min(100.0, priority_input * 0.45 + urgency * 0.35 + task.importance_score * 0.2 - effort_penalty))
        risk = self._risk(task, current)
        confidence = 0.55 + (0.25 if task.deadline else 0.0) + (0.15 if task.estimated_minutes else 0.0)
        reasons: list[str] = []
        if task.deadline:
            deadline = task.deadline if task.deadline.tzinfo else task.deadline.replace(tzinfo=UTC)
            days = (deadline - current).total_seconds() / 86_400
            reasons.append("the deadline is near" if days <= 2 else "the deadline contributes to urgency")
        if task.priority.lower() in {"critical", "urgent", "high"}:
            reasons.append(f"it is marked {task.priority}")
        if task.importance_score >= 70:
            reasons.append("its importance score is high")
        if task.parent_task_id:
            reasons.append("it is connected to a parent task")
        if not reasons:
            reasons.append("its current priority and workload are the strongest available signals")
        explanation = "Recommended because " + ", ".join(reasons) + "."
        return TaskRecommendation(
            priority_score=round(score, 2),
            urgency_score=round(urgency, 2),
            risk_score=round(risk, 2),
            confidence_score=round(min(confidence, 0.95), 2),
            explanation=explanation,
        )

    def _urgency(self, task: TaskModel, now: datetime) -> float:
        if task.deadline is None:
            return 25.0
        deadline = task.deadline
        if deadline.tzinfo is None:
            deadline = deadline.replace(tzinfo=UTC)
        hours = (deadline - now).total_seconds() / 3600
        if hours <= 0:
            return 100.0
        if hours <= 24:
            return 90.0
        if hours <= 72:
            return 75.0
        if hours <= 168:
            return 55.0
        return 30.0

    def _risk(self, task: TaskModel, now: datetime) -> float:
        if task.status in {"completed", "cancelled", "archived", "deleted"}:
            return 0.0
        risk = 15.0
        if task.deadline:
            deadline = task.deadline if task.deadline.tzinfo else task.deadline.replace(tzinfo=UTC)
            days = (deadline - now).total_seconds() / 86_400
            if days < 0:
                risk += 60.0
            elif days <= 2:
                risk += 35.0
            elif days <= 7:
                risk += 15.0
        if task.estimated_minutes >= 240:
            risk += 10.0
        if task.status == "blocked":
            risk += 20.0
        return min(risk, 100.0)


intelligence_service = TaskIntelligenceService()
