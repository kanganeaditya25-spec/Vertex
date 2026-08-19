from __future__ import annotations

from dataclasses import dataclass
from time import perf_counter
from threading import Lock
from typing import Any

from app.core.analytics.metrics import metrics
from app.core.configuration.settings import core_settings


@dataclass(frozen=True)
class PerformanceSnapshot:
    requests: int
    errors: int
    routes: dict[str, dict[str, float | int]]


class PerformanceEngine:
    def __init__(self) -> None:
        self._lock = Lock()
        self._requests = 0
        self._errors = 0
        self._routes: dict[str, dict[str, float | int]] = {}

    def observe(self, route: str, duration_ms: float, status_code: int) -> None:
        normalized = route or '/unknown'
        with self._lock:
            self._requests += 1
            if status_code >= 500:
                self._errors += 1
            entry = self._routes.setdefault(normalized, {'requests': 0, 'errors': 0, 'total_ms': 0.0, 'max_ms': 0.0})
            entry['requests'] = int(entry['requests']) + 1
            entry['errors'] = int(entry['errors']) + (1 if status_code >= 500 else 0)
            entry['total_ms'] = float(entry['total_ms']) + duration_ms
            entry['max_ms'] = max(float(entry['max_ms']), duration_ms)
            if len(self._routes) > core_settings.max_metric_samples:
                oldest = next(iter(self._routes))
                if oldest != normalized:
                    self._routes.pop(oldest, None)
        metrics.increment('http.requests')
        if status_code >= 500:
            metrics.increment('http.errors')
        metrics.observe_ms(f'http.route.{normalized}', duration_ms)

    def snapshot(self) -> PerformanceSnapshot:
        with self._lock:
            routes: dict[str, dict[str, float | int]] = {}
            for route, entry in self._routes.items():
                count = max(1, int(entry['requests']))
                routes[route] = {
                    'requests': int(entry['requests']),
                    'errors': int(entry['errors']),
                    'average_ms': round(float(entry['total_ms']) / count, 3),
                    'max_ms': round(float(entry['max_ms']), 3),
                }
            return PerformanceSnapshot(self._requests, self._errors, routes)

    def reset(self) -> None:
        with self._lock:
            self._requests = 0
            self._errors = 0
            self._routes.clear()


performance = PerformanceEngine()


class PerformanceMiddleware:
    def __init__(self, app: Any) -> None:
        self.app = app

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope.get('type') != 'http':
            await self.app(scope, receive, send)
            return
        started = perf_counter()
        status_code = 500

        async def capture(message: dict[str, Any]) -> None:
            nonlocal status_code
            if message.get('type') == 'http.response.start':
                status_code = int(message.get('status', 500))
            await send(message)

        try:
            await self.app(scope, receive, capture)
        finally:
            duration_ms = (perf_counter() - started) * 1000
            route = scope.get('path', '/unknown')
            performance.observe(route, duration_ms, status_code)
