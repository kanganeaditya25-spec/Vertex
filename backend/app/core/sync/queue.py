from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from threading import RLock
from typing import Any

from app.core.configuration.settings import core_settings

from app.core.utils.common import new_id, utcnow


@dataclass
class SyncOperation:
    entity_type: str
    entity_id: str
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)
    id: str = field(default_factory=lambda: new_id("sync"))
    created_at: datetime = field(default_factory=utcnow)
    acknowledged_at: datetime | None = None
    attempts: int = 0

    def acknowledge(self) -> None:
        self.acknowledged_at = utcnow()


class SyncQueue:
    def __init__(self) -> None:
        self._operations: list[SyncOperation] = []
        self._lock = RLock()

    def enqueue(self, operation: SyncOperation) -> SyncOperation:
        with self._lock:
            self._operations.append(operation)
            if len(self._operations) > core_settings.max_notification_items * 10:
                self._operations = self._operations[-core_settings.max_notification_items * 10:]
        return operation

    def pending(self, limit: int = 100) -> list[SyncOperation]:
        bounded_limit = max(1, min(limit, core_settings.max_notification_items * 2))
        with self._lock:
            return [operation for operation in self._operations if operation.acknowledged_at is None][:bounded_limit]

    def acknowledge(self, operation_id: str) -> bool:
        with self._lock:
            for operation in self._operations:
                if operation.id == operation_id:
                    operation.acknowledge()
                    return True
        return False

    def clear_acknowledged(self) -> int:
        with self._lock:
            before = len(self._operations)
            self._operations = [operation for operation in self._operations if operation.acknowledged_at is None]
            return before - len(self._operations)

    def __len__(self) -> int:
        return len(self.pending(limit=core_settings.max_notification_items * 2))


queue = SyncQueue()
