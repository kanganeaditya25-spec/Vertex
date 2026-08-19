from datetime import datetime, timezone
import uuid
from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


class SettingsSnapshot(Base):
    __tablename__ = "settings_snapshots"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: str(uuid.uuid4()))
    profile_id: Mapped[str] = mapped_column(String(120), default="local", index=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    values: Mapped[dict] = mapped_column(JSON, default=dict)
    favorites: Mapped[list] = mapped_column(JSON, default=list)
    recent_changes: Mapped[list] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now)


class SettingsBackup(Base):
    __tablename__ = "settings_backups"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: str(uuid.uuid4()))
    label: Mapped[str] = mapped_column(String(160), default="Manual backup")
    checksum: Mapped[str] = mapped_column(String(128), default="")
    payload: Mapped[str] = mapped_column(Text, default="{}")
    verified: Mapped[bool] = mapped_column(Boolean, default=False)
    size_bytes: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
