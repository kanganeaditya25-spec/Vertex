from __future__ import annotations

from pathlib import Path

from app.core.configuration.settings import core_settings
from app.core.utils.common import normalize_text


TEXT_EXTENSIONS = {".txt", ".md", ".markdown", ".json", ".csv", ".yaml", ".yml", ".xml", ".html", ".css", ".js", ".ts", ".dart", ".py", ".sql", ".log"}


def extract_text(path: Path) -> str:
    data = path.read_bytes()
    text = data.decode("utf-8", errors="replace")
    normalized = normalize_text(text)
    return normalized[: core_settings.max_preview_chars]


def supports(path: Path) -> bool:
    return path.suffix.casefold() in TEXT_EXTENSIONS
