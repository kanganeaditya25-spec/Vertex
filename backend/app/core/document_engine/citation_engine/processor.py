from __future__ import annotations

from app.core.document_engine.contracts import Citation, ExtractedPage


def build_citations(document_id: str, pages: list[ExtractedPage], source_url: str = "") -> list[Citation]:
    citations: list[Citation] = []
    for page in pages:
        quote = page.text[:280].strip()
        if not quote:
            continue
        locator = source_url or f"page-{page.page_number}"
        citations.append(Citation(label=f"[{len(citations) + 1}]", document_id=document_id, page_number=page.page_number, quote=quote, locator=locator))
    return citations
