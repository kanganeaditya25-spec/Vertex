from __future__ import annotations

from app.core.document_engine.contracts import ProcessedDocument
from app.core.search.index import FullTextIndex, SearchDocument


def index_document(document: ProcessedDocument, index: FullTextIndex) -> None:
    index.upsert(
        SearchDocument(
            document_id=document.document_id,
            title=document.metadata.title or document.source.name,
            text=document.text,
            source_type=document.source.source_kind,
            source_url=document.source.url,
            metadata={
                "asset_id": document.source.asset_id,
                "page_count": document.page_count,
                "chunk_count": len(document.chunks),
                "file_hash": document.metadata.file_hash,
            },
        )
    )
