from __future__ import annotations

from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass, field
from threading import RLock
from typing import Any

from app.core.analytics.metrics import metrics
from app.core.logging.service import logger


@dataclass(frozen=True)
class DomainEvent:
    name: str
    payload: dict[str, Any] = field(default_factory=dict)


EventHandler = Callable[[DomainEvent], None]


@dataclass(frozen=True)
class EventDispatchReport:
    event_name: str
    handler_count: int
    failed_handlers: int


class EventBus:
    def __init__(self) -> None:
        self._handlers: dict[str, list[EventHandler]] = defaultdict(list)
        self._lock = RLock()

    def subscribe(self, event_name: str, handler: EventHandler) -> None:
        with self._lock:
            if handler not in self._handlers[event_name]:
                self._handlers[event_name].append(handler)

    def publish(self, event: DomainEvent) -> EventDispatchReport:
        with self._lock:
            handlers = [*self._handlers.get(event.name, []), *self._handlers.get('*', [])]
        metrics.increment('events.published')
        failures = 0
        for handler in handlers:
            metrics.increment('events.handlers')
            try:
                handler(event)
            except Exception as exc:  # pragma: no cover - defensive subscriber boundary
                failures += 1
                metrics.increment('events.handler_errors')
                logger.error(
                    'Event handler failed',
                    event=event.name,
                    handler=getattr(handler, '__qualname__', repr(handler)),
                    error=str(exc),
                )
        return EventDispatchReport(event.name, len(handlers), failures)

    def clear(self) -> None:
        with self._lock:
            self._handlers.clear()


bus = EventBus()
