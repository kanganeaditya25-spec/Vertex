from fastapi import FastAPI

from app.api.assistant import router as assistant_router
from app.api.analytics import router as analytics_router
from app.api.automation import router as automation_router
from app.api.calendar import router as calendar_router
from app.api.notes import router as notes_router
from app.api.organization import router as organization_router
from app.api.health import router as health_router
from app.api.tasks import router as tasks_router
from app.api.settings import router as settings_router
from app.api.assets import router as assets_router
from app.api.core import router as core_router
from app.api.graph import router as graph_router
from app.api.reminders import router as reminders_router
from app.core.ai import ai_engine as _ai_engine
from app.core.configuration.settings import core_settings
from app.core.event_bus.bus import bus
from app.core.logging.service import configure_logging
from app.core.notifications.service import attach_default_handlers
from app.core.performance.service import PerformanceMiddleware
from app.reminders.events import attach_reminder_event_handlers
from app.graph.service import attach_graph_event_handlers
from app.core.config import settings
from app.db.migrations import ensure_additive_schema
from app.db.session import Base, SessionLocal, engine
from app.models import task as _task_models
from app.calendar import models as _calendar_models
from app.notes import models as _note_models
from app.assistant import models as _assistant_models
from app.organization import models as _organization_models
from app.analytics import models as _analytics_models
from app.automation import models as _automation_models
from app.settings import models as _settings_models
from app.assets import models as _asset_models
from app.reminders import models as _reminder_models
from app.graph import models as _graph_models


configure_logging()

app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Offline-first productivity API foundation",
)
app.add_middleware(PerformanceMiddleware)

app.include_router(health_router, prefix="/api/v1")
app.include_router(tasks_router, prefix="/api/v1")
app.include_router(calendar_router, prefix="/api/v1")
app.include_router(notes_router, prefix="/api/v1")
app.include_router(assistant_router, prefix="/api/v1")
app.include_router(organization_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(automation_router, prefix="/api/v1")
app.include_router(settings_router, prefix="/api/v1")
app.include_router(assets_router, prefix="/api/v1")
app.include_router(core_router, prefix="/api/v1")
app.include_router(graph_router, prefix="/api/v1")
app.include_router(reminders_router, prefix="/api/v1")
Base.metadata.create_all(bind=engine)
ensure_additive_schema(engine)
core_settings.ensure_directories()
attach_default_handlers(bus)
attach_reminder_event_handlers(bus, SessionLocal)
attach_graph_event_handlers(bus, SessionLocal)


@app.on_event("startup")
def initialize_database() -> None:
    Base.metadata.create_all(bind=engine)
    ensure_additive_schema(engine)


@app.get("/", tags=["meta"])
def root() -> dict[str, str]:
    return {
        "service": settings.app_name,
        "version": "0.1.0",
        "health": "/api/v1/health",
        "tasks": "/api/v1/tasks",
        "calendar": "/api/v1/calendar",
        "notes": "/api/v1/notes",
        "assistant": "/api/v1/assistant",
        "organization": "/api/v1/organization",
        "analytics": "/api/v1/analytics",
        "automation": "/api/v1/automation",
        "settings": "/api/v1/settings",
        "assets": "/api/v1/assets",
        "reminders": "/api/v1/reminders",
        "knowledge_graph": "/api/v1/graph",
    }
