from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

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

    def push(self, title: str, message: str, level: str = "info", payload: dict[str, Any] | None = None) -> Notification:
        item = Notification(title=title, message=message, level=level, payload=payload or {})
        self._items.insert(0, item)
        return item

    def list(self, unread_only: bool = False, limit: int = 50) -> list[Notification]:
        items = [item for item in self._items if not unread_only or not item.read]
        return items[:limit]

    def mark_read(self, notification_id: str) -> bool:
        for index, item in enumerate(self._items):
            if item.id == notification_id:
                self._items[index] = Notification(item.title, item.message, item.level, item.id, item.created_at, True, item.payload)
                return True
        return False


center = NotificationCenter()


def attach_default_handlers(event_bus: object) -> None:
    def on_document_processed(event: object) -> None:
        payload = getattr(event, "payload", {})
        document_id = payload.get("document_id", "document")
        center.push("Document ready", f"Document {document_id} is indexed and ready to search.", payload=payload)

    event_bus.subscribe("document.processed", on_document_processed)
