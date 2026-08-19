from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.settings.models import SettingsBackup, SettingsSnapshot
from app.settings.schemas import (
    BackupCreate,
    BackupOut,
    BackupRestore,
    DeveloperStateOut,
    ModelHealthOut,
    PrivacyAction,
    SettingsPatch,
    SettingsSnapshotIn,
    SettingsSnapshotOut,
    StorageStatsOut,
)

router = APIRouter(prefix="/settings", tags=["settings"])

DEFAULT_VALUES: dict[str, Any] = {
    "general": {"username": "", "display_name": "", "timezone": "UTC", "country": "", "date_format": "MMM d, yyyy", "time_format": "24h", "week_start_day": "monday", "default_workspace": "", "default_project": ""},
    "appearance": {"theme_mode": "system", "dynamic_colors": False, "accent_color": "indigo", "font_scale": 1.0, "font_family": "system", "density": "comfortable", "animation_speed": "normal", "high_contrast": False, "reduced_motion": False},
    "ai": {"local_model": "llama3.2", "ollama_endpoint": "http://localhost:11434", "embedding_model": "nomic-embed-text", "temperature": 0.2, "context_length": 8192, "memory_size": 20, "personality": "focused", "auto_summaries": True, "auto_categorization": True, "auto_prioritization": True, "auto_scheduling": False, "suggestions": True},
    "productivity": {"work_start": "09:00", "work_end": "17:00", "focus_minutes": 50, "break_minutes": 10, "pomodoro_minutes": 25, "daily_goal": 3, "weekly_goal": 15, "productivity_target": 75, "default_task_minutes": 30},
    "calendar": {"working_days": [1, 2, 3, 4, 5], "default_view": "week", "buffer_minutes": 10, "meeting_default_minutes": 30, "time_zone": "UTC", "event_colors": {}},
    "tasks": {"default_priority": "medium", "default_category": "general", "auto_archive": False, "auto_complete_rules": True, "recurring_defaults": "weekly", "sorting": "priority", "default_filters": []},
    "notes": {"default_editor": "markdown", "markdown_mode": True, "auto_save_seconds": 10, "version_history": True, "default_folder": "", "default_note_type": "note"},
    "projects": {"default_workspace": "", "default_status": "planning", "milestone_rules": True, "project_templates": True, "goal_templates": True},
    "analytics": {"enabled": True, "default_period": "week", "show_recommendations": True},
    "automation": {"enabled": True, "require_approval": True, "max_steps": 20, "scheduled_runs_when_active": True},
    "notifications": {"local_enabled": True, "sounds": True, "silent_mode": False, "critical_alerts": True, "schedule": "always", "do_not_disturb": False},
    "reminders": {"default_minutes": 15, "snooze_options": [5, 15, 30], "repeat_rules": "none", "smart_reminders": True, "ai_suggestions": True},
    "search": {"history": [], "suggestions": True, "semantic": False, "ocr": False, "voice": False},
    "voice": {"whisper_model": "base", "language": "en", "microphone": True, "voice_activation": False, "speech_speed": 1.0, "offline_recognition": True},
    "security": {"pin_lock": False, "biometrics": False, "auto_lock_minutes": 0, "session_timeout_minutes": 30, "secure_storage": True, "encryption": True},
    "privacy": {"analytics_enabled": False, "ai_memory_enabled": True, "telemetry": False},
    "backup": {"scheduled": False, "schedule": "weekly", "last_backup": None, "verification": True},
    "storage": {"cache_cleanup_days": 30, "temporary_cleanup": True, "optimization": True},
    "accessibility": {"large_text": False, "high_contrast": False, "reduced_motion": False, "screen_reader": True, "keyboard_navigation": True, "color_blind_mode": "none"},
    "language": {"locale": "en", "region": "US"},
    "integrations": {"local_ai": True, "plugin_system": False, "future_cloud_sync": False},
    "developer": {"enabled": False, "debug_logs": False, "event_bus_monitor": False, "api_logs": False, "performance_metrics": False, "feature_flags": {}},
}


def _snapshot(db: Session) -> SettingsSnapshot:
    item = db.scalar(select(SettingsSnapshot).where(SettingsSnapshot.profile_id == "local"))
    if item is None:
        item = SettingsSnapshot(profile_id="local", values=deepcopy(DEFAULT_VALUES), favorites=[], recent_changes=[])
        db.add(item)
        db.commit()
        db.refresh(item)
    return item


def _out(item: SettingsSnapshot) -> SettingsSnapshotOut:
    return SettingsSnapshotOut(id=item.id, profile_id=item.profile_id, version=item.version, values=item.values or {}, favorites=item.favorites or [], recent_changes=item.recent_changes or [], updated_at=item.updated_at)


def _set_path(values: dict[str, Any], path: str, value: Any) -> None:
    parts = [part for part in path.split(".") if part]
    if not parts:
        raise HTTPException(status_code=400, detail="Setting path is required")
    cursor = values
    for part in parts[:-1]:
        current = cursor.get(part)
        if not isinstance(current, dict):
            current = {}
            cursor[part] = current
        cursor = current
    cursor[parts[-1]] = value


def _checksum(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(raw).hexdigest()


@router.get("", response_model=SettingsSnapshotOut)
def get_settings(db: Session = Depends(get_db)) -> SettingsSnapshotOut:
    return _out(_snapshot(db))


@router.put("", response_model=SettingsSnapshotOut)
def replace_settings(payload: SettingsSnapshotIn, db: Session = Depends(get_db)) -> SettingsSnapshotOut:
    item = _snapshot(db)
    item.values = payload.values
    item.favorites = payload.favorites
    item.recent_changes = payload.recent_changes[-30:]
    item.version = max(item.version + 1, payload.version)
    db.commit()
    db.refresh(item)
    return _out(item)


@router.patch("/value", response_model=SettingsSnapshotOut)
def patch_setting(payload: SettingsPatch, db: Session = Depends(get_db)) -> SettingsSnapshotOut:
    item = _snapshot(db)
    values = deepcopy(item.values or {})
    _set_path(values, payload.path, payload.value)
    item.values = values
    item.version += 1
    item.recent_changes = [payload.path, *(item.recent_changes or [])][:30]
    db.commit()
    db.refresh(item)
    return _out(item)


@router.get("/search")
def search_settings(q: str = Query(default="", min_length=0, max_length=100), db: Session = Depends(get_db)) -> list[dict[str, str]]:
    item = _snapshot(db)
    needle = q.strip().lower()
    results: list[dict[str, str]] = []
    for category, values in (item.values or {}).items():
        if not isinstance(values, dict):
            continue
        for key in values:
            label = key.replace("_", " ").title()
            path = f"{category}.{key}"
            if not needle or needle in label.lower() or needle in category.lower() or needle in path.lower():
                results.append({"path": path, "category": category, "label": label})
    return results[:100]


@router.post("/backups", response_model=BackupOut)
def create_backup(payload: BackupCreate, db: Session = Depends(get_db)) -> BackupOut:
    item = _snapshot(db)
    bundle = {"format": "focusflow-settings-v1", "created_at": datetime.now(timezone.utc).isoformat(), "settings": _out(item).model_dump(mode="json")}
    encoded = json.dumps(bundle, sort_keys=True, separators=(",", ":"))
    record = SettingsBackup(label=payload.label, checksum=_checksum(bundle), payload=encoded, verified=True, size_bytes=len(encoded.encode()))
    db.add(record)
    db.commit()
    db.refresh(record)
    return BackupOut(id=record.id, label=record.label, checksum=record.checksum, verified=record.verified, size_bytes=record.size_bytes, created_at=record.created_at)


@router.get("/backups", response_model=list[BackupOut])
def list_backups(db: Session = Depends(get_db)) -> list[BackupOut]:
    records = db.scalars(select(SettingsBackup).order_by(SettingsBackup.created_at.desc())).all()
    return [BackupOut(id=item.id, label=item.label, checksum=item.checksum, verified=item.verified, size_bytes=item.size_bytes, created_at=item.created_at) for item in records]


@router.get("/backups/{backup_id}")
def get_backup(backup_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    item = db.get(SettingsBackup, backup_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Backup not found")
    return {"id": item.id, "label": item.label, "checksum": item.checksum, "verified": item.verified, "payload": json.loads(item.payload)}


@router.post("/backups/{backup_id}/restore", response_model=SettingsSnapshotOut)
def restore_backup(backup_id: str, payload: BackupRestore | None = None, db: Session = Depends(get_db)) -> SettingsSnapshotOut:
    item = db.get(SettingsBackup, backup_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Backup not found")
    bundle = json.loads(item.payload)
    if _checksum(bundle) != item.checksum:
        raise HTTPException(status_code=409, detail="Backup verification failed")
    settings_payload = bundle.get("settings") or {}
    snapshot = _snapshot(db)
    snapshot.values = settings_payload.get("values", DEFAULT_VALUES)
    snapshot.favorites = settings_payload.get("favorites", [])
    snapshot.recent_changes = ["backup.restore", *(snapshot.recent_changes or [])][:30]
    snapshot.version += 1
    db.commit()
    db.refresh(snapshot)
    return _out(snapshot)


@router.post("/privacy")
def privacy_action(payload: PrivacyAction, db: Session = Depends(get_db)) -> dict[str, Any]:
    if payload.action in {"delete_local_data", "clear_ai_memory", "delete_search_history", "clear_cache"} and not payload.confirm:
        raise HTTPException(status_code=400, detail="Confirmation is required for this privacy action")
    item = _snapshot(db)
    values = deepcopy(item.values or {})
    if payload.action == "delete_search_history":
        values.setdefault("search", {})["history"] = []
    elif payload.action == "clear_ai_memory":
        values.setdefault("privacy", {})["ai_memory_enabled"] = False
    elif payload.action == "clear_cache":
        values.setdefault("storage", {})["last_cache_cleanup"] = datetime.now(timezone.utc).isoformat()
    elif payload.action == "disable_analytics":
        values.setdefault("analytics", {})["enabled"] = False
        values.setdefault("privacy", {})["analytics_enabled"] = False
    elif payload.action == "delete_local_data":
        values = deepcopy(DEFAULT_VALUES)
    else:
        raise HTTPException(status_code=400, detail="Unsupported privacy action")
    item.values = values
    item.version += 1
    item.recent_changes = [f"privacy.{payload.action}", *(item.recent_changes or [])][:30]
    db.commit()
    return {"action": payload.action, "completed": True, "version": item.version}


@router.get("/storage", response_model=StorageStatsOut)
def storage_stats(db: Session = Depends(get_db)) -> StorageStatsOut:
    settings_bytes = len(json.dumps(_snapshot(db).values or {}).encode())
    backup_bytes = sum(item.size_bytes for item in db.scalars(select(SettingsBackup)).all())
    database_path = Path("data/productivity.db")
    database_bytes = database_path.stat().st_size if database_path.exists() else 0
    return StorageStatsOut(settings_bytes=settings_bytes, backup_bytes=backup_bytes, database_bytes=database_bytes, cache_bytes=0, model_bytes=0, free_space_bytes=None)


@router.get("/ai/health", response_model=ModelHealthOut)
def ai_health(db: Session = Depends(get_db)) -> ModelHealthOut:
    values = _snapshot(db).values or {}
    config = values.get("ai", {}) if isinstance(values.get("ai"), dict) else {}
    endpoint = str(config.get("ollama_endpoint", "http://localhost:11434"))
    return ModelHealthOut(provider="ollama", endpoint=endpoint, available=False, message="Local model health is checked by the client when Ollama is available.")


@router.get("/developer", response_model=DeveloperStateOut)
def developer_state(db: Session = Depends(get_db)) -> DeveloperStateOut:
    values = _snapshot(db).values or {}
    developer = values.get("developer", {}) if isinstance(values.get("developer"), dict) else {}
    return DeveloperStateOut(enabled=bool(developer.get("enabled", False)), feature_flags=developer.get("feature_flags", {}), sync_status="offline-ready", logs=[])
