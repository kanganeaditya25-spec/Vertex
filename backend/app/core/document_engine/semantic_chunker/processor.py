from __future__ import annotations

from app.core.configuration.settings import core_settings
from app.core.document_engine.contracts import SemanticChunk
from app.core.utils.common import normalize_text, tokenize


def chunk_text(text: str, document_id: str = "", page_number: int | None = None, max_chars: int | None = None, overlap: int | None = None) -> list[SemanticChunk]:
    normalized = normalize_text(text)
    if not normalized:
        return []
    max_size = max_chars or core_settings.semantic_chunk_chars
    overlap_size = min(overlap if overlap is not None else core_settings.semantic_chunk_overlap, max_size // 2)
    chunks: list[SemanticChunk] = []
    start = 0
    index = 0
    while start < len(normalized):
        end = min(len(normalized), start + max_size)
        if end < len(normalized):
            boundary = normalized.rfind(" ", start, end)
            if boundary > start + max_size // 2:
                end = boundary
        value = normalized[start:end].strip()
        if value:
            chunks.append(SemanticChunk(text=value, index=index, document_id=document_id, page_number=page_number, start_offset=start, end_offset=end, token_count=len(tokenize(value))))
            index += 1
        if end >= len(normalized):
            break
        start = max(0, end - overlap_size)
    return chunks
