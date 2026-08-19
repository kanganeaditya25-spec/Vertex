from __future__ import annotations

from dataclasses import asdict
from typing import Any

from fastapi import APIRouter, Query

from app.core.ai import ai_engine
from app.core.analytics.metrics import metrics
from app.core.notifications.service import center
from app.core.performance.service import performance
from app.core.search.index import index
from app.core.sync.queue import queue

router = APIRouter(prefix="/core", tags=["core infrastructure"])


@router.get("/capabilities")
def capabilities() -> dict[str, Any]:
    return {
        "modules": ["ai", "analytics", "configuration", "event_bus", "search", "storage", "sync", "security", "notifications", "logging", "performance"],
        "ai": {"active_provider": ai_engine.capabilities().active_provider, "providers": list(ai_engine.capabilities().providers), "network_required": ai_engine.capabilities().network_required},
        "document_engine": ["pdf_processor", "docx_processor", "markdown_processor", "ocr_processor", "preview_generator", "thumbnail_generator", "metadata_extractor", "text_extractor", "document_indexer", "url_extractor", "webpage_parser", "citation_engine", "semantic_chunker"],
        "privacy": {"telemetry_default": False, "search_index": "in_memory_runtime_index", "logging_redacts_secrets": True},
    }


@router.get("/search")
def core_search(q: str = Query(min_length=1), workspace_id: str = '', limit: int = Query(default=20, ge=1, le=100)) -> list[dict[str, Any]]:
    hits = index.search(q, limit=min(limit * 4, 100))
    if workspace_id:
        hits = [hit for hit in hits if hit.metadata.get('workspace_id', '') in {'', workspace_id}]
    return [asdict(hit) for hit in hits[:limit]]


@router.get("/performance")
def core_performance() -> dict[str, Any]:
    snapshot = performance.snapshot()
    return {"requests": snapshot.requests, "errors": snapshot.errors, "routes": snapshot.routes}


@router.get("/metrics")
def core_metrics() -> dict[str, Any]:
    snapshot = metrics.snapshot()
    return {"counters": snapshot.counters, "timings_ms": snapshot.timings_ms}


@router.get("/notifications")
def core_notifications(unread_only: bool = False, limit: int = Query(default=50, ge=1, le=100)) -> list[dict[str, Any]]:
    return [asdict(item) for item in center.list(unread_only=unread_only, limit=limit)]


@router.post("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: str) -> dict[str, bool]:
    return {"acknowledged": center.mark_read(notification_id)}


@router.get("/sync/pending")
def core_sync_pending(limit: int = Query(default=100, ge=1, le=500)) -> list[dict[str, Any]]:
    return [asdict(operation) for operation in queue.pending(limit=limit)]


@router.post("/sync/{operation_id}/ack")
def acknowledge_sync(operation_id: str) -> dict[str, bool]:
    return {"acknowledged": queue.acknowledge(operation_id)}
