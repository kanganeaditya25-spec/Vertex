from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


def _id() -> str:
    return str(uuid4())


def _now() -> datetime:
    return datetime.now(UTC)


class FocusSession(Base):
    __tablename__ = "analytics_focus_sessions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    session_type: Mapped[str] = mapped_column(String(32), default="deep_work", nullable=False)
    interruptions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    project_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    goal_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    notes: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class AnalyticsSnapshot(Base):
    __tablename__ = "analytics_snapshots"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    period: Mapped[str] = mapped_column(String(24), nullable=False, index=True)
    range_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    range_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    metrics: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)


class AnalyticsDashboardLayout(Base):
    __tablename__ = "analytics_dashboard_layouts"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=_id)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    widgets: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now, nullable=False)
