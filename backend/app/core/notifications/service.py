from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from threading import RLock
from typing import Any

from app.core.configuration.settings import core_settings

from app.core.utils.common import new_id, utcnow


@dataclass(frozen=True)
class Notification:
    title: str
    message: str
    level: str = "info"
    id: str = field(default_factory=lambda: new_id("notification"))
    created_at: datetime = field(default_factory=utcnow)
    read: bool = False
    payload: dict[str, Any] = field(default_factory=dict)


class NotificationCenter:
    def __init__(self) -> None:
        self._items: list[Notification] = []
        self._lock = RLock()

    def push(self, title: str, message: str, level: str = 'info', payload: dict[str, Any] | None = None) -> Notification:
        item = Notification(title=title, message=message, level=level, payload=payload or {})
        with self._lock:
            self._items.insert(0, item)
            del self._items[core_settings.max_notification_items:]
        return item

    def list(self, unread_only: bool = False, limit: int = 50) -> list[Notification]:
        bounded_limit = max(1, min(limit, core_settings.max_notification_items))
        with self._lock:
            items = [item for item in self._items if not unread_only or not item.read]
            return items[:bounded_limit]

    def mark_read(self, notification_id: str) -> bool:
        with self._lock:
            for index, item in enumerate(self._items):
                if item.id == notification_id:
                    self._items[index] = Notification(
                        item.title, item.message, item.level, item.id,
                        item.created_at, True, item.payload)
                    return True
        return False

    def clear(self) -> None:
        with self._lock:
            self._items.clear()


center = NotificationCenter()

_EVENT_MESSAGES = {
    'project.created': ('Project created', 'info'),
    'project.updated': ('Project updated', 'info'),
    'project.archived': ('Project archived', 'info'),
    'project.milestone.created': ('Milestone created', 'info'),
    'project.milestone.updated': ('Milestone updated', 'info'),
    'project.milestone.deleted': ('Milestone deleted', 'info'),
    'task.completed': ('Task completed', 'success'),
    'reminder.created': ('Reminder created', 'info'),
    'reminder.triggered': ('Reminder due', 'warning'),
    'automation.workflow.completed': ('Workflow completed', 'success'),
}


def _on_domain_event(event: object) -> None:
    event_name = str(getattr(event, 'name', ''))
    payload = getattr(event, 'payload', {})
    if event_name == 'document.processed':
        document_id = payload.get('document_id', 'document')
        center.push('Document ready', f'Document {document_id} is indexed and ready to search.', payload=payload)
        return
    title_level = _EVENT_MESSAGES.get(event_name)
    if title_level is None:
        return
    title, level = title_level
    entity_id = payload.get('project_id') or payload.get('task_id') or payload.get('reminder_id') or payload.get('milestone_id')
    suffix = f' ({entity_id})' if entity_id else ''
    center.push(title, f'{title}{suffix}.', level=level, payload=payload)


def attach_default_handlers(event_bus: object) -> None:
    event_bus.subscribe('*', _on_domain_event)
