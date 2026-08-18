from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from app.calendar.models import EventModel
from app.models.task import TaskModel


@dataclass(frozen=True)
class Conflict:
    conflict_type: str
    severity: str
    event_ids: list[str]
    message: str
    suggested_resolution: str


@dataclass(frozen=True)
class ScheduleRecommendation:
    task_id: str
    start_at: datetime
    end_at: datetime
    score: float
    explanation: str
    break_after_minutes: int


_PRIORITY_SCORE = {"critical": 100, "urgent": 90, "high": 75, "medium": 50, "low": 25, "someday": 10}


class TimeIntelligenceService:
    """Transparent local scheduling rules; no model or network is required."""

    def detect_conflicts(self, events: list[EventModel]) -> list[Conflict]:
        active = [event for event in events if event.deleted_at is None and event.status != "cancelled"]
        conflicts: list[Conflict] = []
        for index, first in enumerate(active):
            for second in active[index + 1 :]:
                if first.end_at <= second.start_at or second.end_at <= first.start_at:
                    continue
                if first.locked and second.locked:
                    severity = "critical"
                    resolution = "Review one locked event manually before moving either event."
                elif first.locked or second.locked:
                    severity = "high"
                    resolution = "Keep the locked event and move the flexible event to the next free slot."
                else:
                    severity = "moderate"
                    resolution = "Move the lower-priority flexible event or shorten the overlap."
                conflicts.append(Conflict("overlap", severity, [first.id, second.id], f"{first.title} overlaps {second.title}.", resolution))
        return conflicts

    def schedule(
        self,
        tasks: list[TaskModel],
        events: list[EventModel],
        window_start: datetime,
        window_end: datetime,
        energy_level: str,
        include_breaks: bool,
    ) -> list[ScheduleRecommendation]:
        current = _aware(window_start)
        end = _aware(window_end)
        occupied = sorted((_aware(event.start_at), _aware(event.end_at)) for event in events if event.deleted_at is None and event.status != "cancelled")
        candidates = sorted(
            [task for task in tasks if task.status not in {"completed", "cancelled", "archived", "deleted"}],
            key=lambda task: (-_PRIORITY_SCORE.get(task.priority.lower(), 50), task.deadline or datetime.max.replace(tzinfo=UTC), -task.importance_score),
        )
        recommendations: list[ScheduleRecommendation] = []
        for task in candidates:
            duration = timedelta(minutes=max(task.estimated_minutes or 25, 15))
            slot = _next_free_slot(current, end, duration, occupied)
            if slot is None:
                break
            slot_start, slot_end = slot
            energy_match = task.energy_level.lower() in {energy_level.lower(), "medium"} or energy_level.lower() == "medium"
            deadline_note = "before its deadline" if task.deadline else "during the next available working window"
            explanation = f"Scheduled {task.title} {deadline_note}; priority, estimated effort, and available time were considered."
            if not energy_match:
                explanation += f" The task requests {task.energy_level} energy while this window is {energy_level}."
            break_minutes = 10 if include_breaks and duration >= timedelta(minutes=50) else 0
            recommendations.append(ScheduleRecommendation(task.id, slot_start, slot_end, round(_score(task, energy_match), 2), explanation, break_minutes))
            occupied.append((slot_start, slot_end + timedelta(minutes=break_minutes)))
            occupied.sort()
            current = slot_end + timedelta(minutes=break_minutes)
        return recommendations

    def deadline_risk(self, task: TaskModel, available_minutes: int) -> tuple[str, float, str]:
        remaining = max(task.estimated_minutes - task.actual_minutes, 0)
        if remaining == 0:
            return "safe", 0.0, "The estimated effort is complete."
        if available_minutes >= remaining * 2:
            return "safe", 0.2, "There is ample available time for the remaining effort."
        if available_minutes >= remaining:
            return "moderate", 0.5, "The remaining effort fits, but there is limited schedule slack."
        return "high", 0.85, "The remaining effort exceeds the available time; schedule a focused block or reduce scope."


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _next_free_slot(start: datetime, end: datetime, duration: timedelta, occupied: list[tuple[datetime, datetime]]) -> tuple[datetime, datetime] | None:
    cursor = start
    for occupied_start, occupied_end in occupied:
        if occupied_end <= cursor:
            continue
        if occupied_start - cursor >= duration:
            return cursor, cursor + duration
        cursor = max(cursor, occupied_end)
        if cursor >= end:
            return None
    return (cursor, cursor + duration) if cursor + duration <= end else None


def _score(task: TaskModel, energy_match: bool) -> float:
    base = _PRIORITY_SCORE.get(task.priority.lower(), 50)
    return min(100.0, base * 0.6 + (20 if energy_match else 5) + min(task.importance_score, 100) * 0.2)


intelligence_service = TimeIntelligenceService()
