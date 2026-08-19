from __future__ import annotations

import html
from pathlib import Path

from app.core.configuration.settings import core_settings
from app.core.document_engine.contracts import ProcessedDocument
from app.core.utils.common import new_id, safe_filename


def generate_preview(document: ProcessedDocument, output_root: Path) -> Path:
    output_root.mkdir(parents=True, exist_ok=True)
    stem = safe_filename(Path(document.source.name).stem, fallback=new_id("document"))
    path = output_root / f"{stem}-{document.document_id[:12]}.html"
    title = html.escape(document.metadata.title or document.source.name)
    content = html.escape(document.text[: core_settings.max_preview_chars])
    body = f"<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>{title}</title></head><body><article><h1>{title}</h1><pre>{content}</pre></article></body></html>"
    path.write_text(body, encoding="utf-8")
    return path
