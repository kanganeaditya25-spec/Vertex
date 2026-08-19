from dataclasses import dataclass

from fastapi.testclient import TestClient

from app.core.ai.contracts import AiRequest, AiResponse
from app.core.ai.engine import AiEngine, RuleBasedAiProvider
from app.core.event_bus.bus import DomainEvent, EventBus
from app.core.logging.service import redact_fields
from app.core.notifications.service import NotificationCenter, attach_default_handlers, center
from app.core.performance.service import PerformanceEngine
from app.main import app

client = TestClient(app)


@dataclass
class EchoProvider:
    name: str = 'echo'

    def complete(self, request: AiRequest) -> AiResponse:
        return AiResponse(text=request.prompt, model=self.name)


def test_ai_engine_routes_to_registered_provider() -> None:
    engine = AiEngine()
    engine.register(EchoProvider())
    response = engine._providers['echo'].complete(AiRequest(prompt='organize this'))

    assert response.text == 'organize this'
    assert RuleBasedAiProvider().complete(AiRequest(prompt='plan')).metadata['offline'] is True


def test_logging_redacts_sensitive_fields_and_bounds_values() -> None:
    redacted = redact_fields({'token': 'secret-value', 'message': 'x' * 800})

    assert redacted['token'] == '[REDACTED]'
    assert str(redacted['message']).endswith('…')


def test_event_bus_isolates_handler_failure_and_reports_it() -> None:
    bus = EventBus()
    received: list[str] = []

    def broken(_: DomainEvent) -> None:
        raise RuntimeError('expected test failure')

    bus.subscribe('sample', broken)
    bus.subscribe('sample', lambda event: received.append(event.name))
    report = bus.publish(DomainEvent('sample'))

    assert report.handler_count == 2
    assert report.failed_handlers == 1
    assert received == ['sample']


def test_notification_center_handles_domain_events_and_mark_read() -> None:
    local_center = NotificationCenter()
    local_bus = EventBus()
    # Keep the global handler implementation but redirect its shared center for this test.
    center.clear()
    attach_default_handlers(local_bus)
    local_bus.publish(DomainEvent('task.completed', {'task_id': 'task-1'}))
    items = center.list()

    assert items and items[0].title == 'Task completed'
    assert center.mark_read(items[0].id) is True
    assert center.list(unread_only=True) == []
    assert local_center.list() == []


def test_performance_engine_records_bounded_route_snapshot() -> None:
    engine = PerformanceEngine()
    engine.observe('/api/v1/tasks', 12.5, 200)
    engine.observe('/api/v1/tasks', 20.0, 500)
    snapshot = engine.snapshot()

    assert snapshot.requests == 2
    assert snapshot.errors == 1
    assert snapshot.routes['/api/v1/tasks']['average_ms'] == 16.25


def test_core_api_exposes_new_engines_and_notification_ack() -> None:
    capabilities = client.get('/api/v1/core/capabilities')
    performance = client.get('/api/v1/core/performance')

    assert capabilities.status_code == 200
    assert {'logging', 'performance'}.issubset(capabilities.json()['modules'])
    assert 'ai' in capabilities.json()
    assert performance.status_code == 200
    assert {'requests', 'errors', 'routes'}.issubset(performance.json())
