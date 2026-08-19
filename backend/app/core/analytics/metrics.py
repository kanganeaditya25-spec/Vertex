from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from threading import Lock


@dataclass(frozen=True)
class MetricSnapshot:
    counters: dict[str, int]
    timings_ms: dict[str, float]


class Metrics:
    def __init__(self) -> None:
        self._counters: Counter[str] = Counter()
        self._timings: dict[str, list[float]] = {}
        self._lock = Lock()

    def increment(self, name: str, amount: int = 1) -> None:
        with self._lock:
            self._counters[name] += amount

    def observe_ms(self, name: str, duration_ms: float) -> None:
        with self._lock:
            self._timings.setdefault(name, []).append(duration_ms)

    def snapshot(self) -> MetricSnapshot:
        with self._lock:
            averages = {name: sum(values) / len(values) for name, values in self._timings.items() if values}
            return MetricSnapshot(dict(self._counters), averages)

    def reset(self) -> None:
        with self._lock:
            self._counters.clear()
            self._timings.clear()


metrics = Metrics()
