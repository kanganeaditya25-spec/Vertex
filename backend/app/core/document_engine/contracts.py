from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from app.core.utils.common import new_id, utcnow


@dataclass(frozen=True)
class DocumentSource:
    name: str
    path: Path | None = None
    url: str = ""
    mime_type: str = "application/octet-stream"
    source_kind: str = "file"
    asset_id: str = ""


@dataclass(frozen=True)
class ExtractedPage:
    page_number: int
    text: str
    title: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class DocumentMetadata:
    name: str
    extension: str
    mime_type: str
    size_bytes: int
    file_hash: str = ""
    page_count: int = 0
    language: str = ""
    author: str = ""
    title: str = ""
    created_at: datetime | None = None
    modified_at: datetime | None = None
    extra: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Citation:
    label: str
    document_id: str
    page_number: int | None = None
    quote: str = ""
    locator: str = ""


@dataclass(frozen=True)
class SemanticChunk:
    text: str
    index: int
    document_id: str = ""
    page_number: int | None = None
    start_offset: int = 0
    end_offset: int = 0
    token_count: int = 0
    chunk_id: str = field(default_factory=lambda: new_id("chunk"))


@dataclass
class ProcessedDocument:
    source: DocumentSource
    metadata: DocumentMetadata
    pages: list[ExtractedPage] = field(default_factory=list)
    text: str = ""
    chunks: list[SemanticChunk] = field(default_factory=list)
    citations: list[Citation] = field(default_factory=list)
    preview_path: Path | None = None
    thumbnail_path: Path | None = None
    warnings: list[str] = field(default_factory=list)
    processed_at: datetime = field(default_factory=utcnow)

    @property
    def document_id(self) -> str:
        return self.source.asset_id or self.metadata.file_hash or self.source.name

    @property
    def page_count(self) -> int:
        return self.metadata.page_count or len(self.pages)
