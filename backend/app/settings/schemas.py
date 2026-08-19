from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field


class SettingsSnapshotIn(BaseModel):
    values: dict[str, Any] = Field(default_factory=dict)
    favorites: list[str] = Field(default_factory=list)
    recent_changes: list[str] = Field(default_factory=list)
    version: int = 1


class SettingsSnapshotOut(SettingsSnapshotIn):
    id: str
    profile_id: str
    updated_at: datetime


class SettingsPatch(BaseModel):
    path: str = Field(min_length=1, max_length=160)
    value: Any


class BackupCreate(BaseModel):
    label: str = Field(default="Manual backup", max_length=160)
    include_settings: bool = True
    include_templates: bool = True


class BackupOut(BaseModel):
    id: str
    label: str
    checksum: str
    verified: bool
    size_bytes: int
    created_at: datetime


class BackupRestore(BaseModel):
    payload: dict[str, Any] = Field(default_factory=dict)
    checksum: str | None = None


class PrivacyAction(BaseModel):
    action: str
    confirm: bool = False


class StorageStatsOut(BaseModel):
    settings_bytes: int
    backup_bytes: int
    database_bytes: int
    cache_bytes: int
    model_bytes: int
    free_space_bytes: int | None = None


class ModelHealthOut(BaseModel):
    provider: str
    endpoint: str
    available: bool
    message: str


class DeveloperStateOut(BaseModel):
    enabled: bool
    feature_flags: dict[str, bool]
    sync_status: str
    logs: list[str]
