from fastapi import FastAPI

from app.api.calendar import router as calendar_router
from app.api.health import router as health_router
from app.api.tasks import router as tasks_router
from app.core.config import settings
from app.db.session import Base, engine
from app.models import task as _task_models
from app.calendar import models as _calendar_models


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Offline-first productivity API foundation",
)

app.include_router(health_router, prefix="/api/v1")
app.include_router(tasks_router, prefix="/api/v1")
app.include_router(calendar_router, prefix="/api/v1")
Base.metadata.create_all(bind=engine)


@app.on_event("startup")
def initialize_database() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/", tags=["meta"])
def root() -> dict[str, str]:
    return {
        "service": settings.app_name,
        "version": "0.1.0",
        "health": "/api/v1/health",
        "tasks": "/api/v1/tasks",
        "calendar": "/api/v1/calendar",
    }
