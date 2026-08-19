from __future__ import annotations

import re
from pathlib import Path

from app.core.document_engine.contracts import DocumentMetadata, DocumentSource, ExtractedPage
from app.core.utils.common import extension_for, mime_type_for, normalize_text, sha256_bytes


def process_markdown(path: Path, source: DocumentSource | None = None) -> tuple[DocumentMetadata, list[ExtractedPage]]:
    raw = path.read_text(encoding="utf-8", errors="replace")
    sections = re.split(r"(?=^#{1,6}\s+)", raw, flags=re.MULTILINE)
    pages: list[ExtractedPage] = []
    for index, section in enumerate((section for section in sections if section.strip()), start=1):
        heading = next((line.lstrip("# ").strip() for line in section.splitlines() if line.startswith("#")), "")
        pages.append(ExtractedPage(page_number=index, title=heading, text=normalize_text(section)))
    text = normalize_text(raw)
    metadata = DocumentMetadata(
        name=path.name,
        extension=extension_for(path.name),
        mime_type=mime_type_for(path.name),
        size_bytes=path.stat().st_size,
        file_hash=sha256_bytes(path.read_bytes()),
        page_count=len(pages),
        title=pages[0].title if pages else path.stem,
        extra={"heading_sections": len(pages)},
    )
    return metadata, pages or [ExtractedPage(page_number=1, text=text)]
