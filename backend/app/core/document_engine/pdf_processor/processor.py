from __future__ import annotations

from pathlib import Path

from pypdf import PdfReader

from app.core.document_engine.contracts import DocumentMetadata, DocumentSource, ExtractedPage
from app.core.utils.common import extension_for, mime_type_for, normalize_text, sha256_bytes


def process_pdf(path: Path, source: DocumentSource | None = None) -> tuple[DocumentMetadata, list[ExtractedPage]]:
    reader = PdfReader(str(path))
    pages = [ExtractedPage(page_number=index + 1, text=normalize_text(page.extract_text() or "")) for index, page in enumerate(reader.pages)]
    info = reader.metadata or {}
    metadata = DocumentMetadata(
        name=path.name,
        extension=extension_for(path.name),
        mime_type=mime_type_for(path.name),
        size_bytes=path.stat().st_size,
        file_hash=sha256_bytes(path.read_bytes()),
        page_count=len(pages),
        author=str(info.get("/Author", "") or ""),
        title=str(info.get("/Title", "") or ""),
        extra={"producer": str(info.get("/Producer", "") or "")},
    )
    return metadata, pages
