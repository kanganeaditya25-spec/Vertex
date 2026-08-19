from __future__ import annotations

from calendar import monthrange
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any

from app.reminders.models import ReminderPreferenceModel, ReminderRecordModel


@dataclass(frozen=True)
class DueDecision:
    reminder: ReminderRecordModel
    delayed: bool
    delay_reason: str = ""


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def next_occurrence(at: datetime, repeat_rule: dict[str, Any], now: datetime | None = None) -> datetime | None:
    kind = str(repeat_rule.get("kind", "")).casefold()
    interval = max(1, int(repeat_rule.get("interval", 1)))
    current = _aware(at)
    if not kind or kind in {"none", "one_time", "once"}:
        return None
    if kind == "interval":
        return current + timedelta(minutes=max(1, int(repeat_rule.get("minutes", 60))) * interval)
    if kind == "daily":
        return current + timedelta(days=interval)
    if kind == "weekly":
        weekdays = repeat_rule.get("weekdays")
        if isinstance(weekdays, list) and weekdays:
            allowed = {int(day) % 7 for day in weekdays}
            candidate = current + timedelta(days=1)
            while candidate.weekday() not in allowed:
                candidate += timedelta(days=1)
            return candidate
        return current + timedelta(weeks=interval)
    if kind == "monthly":
        month_index = current.month - 1 + interval
        year = current.year + month_index // 12
        month = month_index % 12 + 1
        day = min(current.day, monthrange(year, month)[1])
        return current.replace(year=year, month=month, day=day)
    if kind == "yearly":
        try:
            return current.replace(year=current.year + interval)
        except ValueError:
            return current.replace(year=current.year + interval, day=28)
    if kind == "custom":
        return current + timedelta(days=max(1, int(repeat_rule.get("days", 1))) * interval)
    return None


def is_quiet(now: datetime, preferences: ReminderPreferenceModel) -> tuple[bool, str]:
    local = _aware(now)
    minute = local.hour * 60 + local.minute
    if preferences.quiet_hours_enabled:
        start = preferences.quiet_start_minutes
        end = preferences.quiet_end_minutes
        in_quiet = minute >= start or minute < end if start > end else start <= minute < end
        if in_quiet:
            return True, "quiet_hours"
    if preferences.sleep_schedule_enabled and (minute >= 22 * 60 or minute < 7 * 60):
        return True, "sleep_schedule"
    return False, ""


def priority_score(reminder: ReminderRecordModel, now: datetime | None = None) -> float:
    current = _aware(now or datetime.now(UTC))
    score = (6 - reminder.priority) * 20.0
    if reminder.next_trigger_at:
        delta_minutes = (_aware(reminder.next_trigger_at) - current).total_seconds() / 60
        if delta_minutes < 0:
            score += min(80.0, 40.0 + abs(delta_minutes) / 60)
        elif delta_minutes <= 60:
            score += 30.0
        elif delta_minutes <= 24 * 60:
            score += 15.0
    score += min(20.0, reminder.snoozed_count * 2.5)
    if reminder.trigger_type in {"deadline", "task_overdue", "project_deadline"}:
        score += 20.0
    if reminder.notification_type == "critical":
        score += 25.0
    return round(score, 2)


def due_decisions(reminders: list[ReminderRecordModel], preferences: ReminderPreferenceModel, now: datetime | None = None) -> list[DueDecision]:
    current = _aware(now or datetime.now(UTC))
    quiet, reason = is_quiet(current, preferences)
    decisions: list[DueDecision] = []
    for reminder in reminders:
        if reminder.status not in {"scheduled", "triggered"} or reminder.next_trigger_at is None:
            continue
        if _aware(reminder.next_trigger_at) > current:
            continue
        critical = reminder.priority == 1 or reminder.notification_type == "critical"
        if quiet and not critical:
            decisions.append(DueDecision(reminder, True, reason))
        else:
            decisions.append(DueDecision(reminder, False, ""))
    decisions.sort(key=lambda item: priority_score(item.reminder, current), reverse=True)
    return decisions


def group_key(reminder: ReminderRecordModel, grouping: str, now: datetime | None = None) -> str:
    current = _aware(now or datetime.now(UTC))
    trigger = _aware(reminder.next_trigger_at) if reminder.next_trigger_at else None
    if grouping == "priority":
        return f"priority-{reminder.priority}"
    if grouping == "workspace":
        return reminder.workspace_id or "unassigned"
    if grouping == "project":
        return reminder.project_id or "unassigned"
    if grouping == "goal":
        return reminder.goal_id or "unassigned"
    if trigger is None:
        return "unscheduled"
    day = trigger.date()
    if day < current.date():
        return "overdue"
    if day == current.date():
        return "today"
    if day == (current + timedelta(days=1)).date():
        return "tomorrow"
    if day <= (current + timedelta(days=6 - current.weekday())).date():
        return "this_week"
    return "later"


def smart_suggestions(reminders: list[ReminderRecordModel], history_by_id: dict[str, list[Any]], now: datetime | None = None) -> list[dict[str, Any]]:
    current = _aware(now or datetime.now(UTC))
    suggestions: list[dict[str, Any]] = []
    for reminder in reminders:
        history = history_by_id.get(reminder.id, [])
        snoozes = sum(getattr(item, "action", "") == "snooze" for item in history)
        if snoozes >= 2 and reminder.next_trigger_at:
            candidate = _aware(reminder.next_trigger_at) + timedelta(hours=1)
            suggestions.append({"reminder_id": reminder.id, "recommendation": "Move reminder one hour later", "reason": f"This reminder was snoozed {snoozes} times; a later time may reduce interruption.", "suggested_trigger_at": candidate, "confidence": min(0.95, 0.55 + snoozes * 0.08)})
        elif reminder.next_trigger_at and _aware(reminder.next_trigger_at) < current and reminder.priority <= 2:
            candidate = current + timedelta(minutes=15)
            suggestions.append({"reminder_id": reminder.id, "recommendation": "Schedule a near-term catch-up", "reason": "This high-priority reminder is overdue and has not been completed.", "suggested_trigger_at": candidate, "confidence": 0.82})
    return suggestions
