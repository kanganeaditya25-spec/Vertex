from __future__ import annotations

from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, field
from threading import RLock
from typing import Any


@dataclass(frozen=True)
class DomainEvent:
    name: str
    payload: dict[str, Any] = field(default_factory=dict)


EventHandler = Callable[[DomainEvent], None]


class EventBus:
    def __init__(self) -> None:
        self._handlers: dict[str, list[EventHandler]] = defaultdict(list)
        self._lock = RLock()

    def subscribe(self, event_name: str, handler: EventHandler) -> None:
        with self._lock:
            if handler not in self._handlers[event_name]:
                self._handlers[event_name].append(handler)

    def publish(self, event: DomainEvent) -> None:
        with self._lock:
            handlers = [*self._handlers.get(event.name, []), *self._handlers.get("*", [])]
        for handler in handlers:
            handler(event)

    def clear(self) -> None:
        with self._lock:
            self._handlers.clear()


bus = EventBus()
