from __future__ import annotations

from pathlib import Path

from app.core.analytics.metrics import metrics
from app.core.configuration.settings import core_settings
from app.core.document_engine.citation_engine.processor import build_citations
from app.core.document_engine.contracts import DocumentMetadata, DocumentSource, ExtractedPage, ProcessedDocument
from app.core.document_engine.document_indexer.processor import index_document
from app.core.document_engine.docx_processor.processor import process_docx
from app.core.document_engine.markdown_processor.processor import process_markdown
from app.core.document_engine.metadata_extractor.processor import extract_metadata
from app.core.document_engine.ocr_processor.processor import extract_ocr, supports as ocr_supports
from app.core.document_engine.pdf_processor.processor import process_pdf
from app.core.document_engine.preview_generator.processor import generate_preview
from app.core.document_engine.semantic_chunker.processor import chunk_text
from app.core.document_engine.text_extractor.processor import extract_text, supports as text_supports
from app.core.document_engine.thumbnail_generator.processor import generate_thumbnail
from app.core.document_engine.webpage_parser.processor import parse_webpage
from app.core.event_bus.bus import DomainEvent, bus
from app.core.search.index import FullTextIndex, index
from app.core.utils.common import normalize_text


class DocumentEngine:
    def __init__(self, search_index: FullTextIndex | None = None) -> None:
        self.search_index = search_index or index

    def process(self, source: DocumentSource, generate_assets: bool = True) -> ProcessedDocument:
        if source.url and not source.path:
            return self._process_url(source)
        if source.path is None:
            raise ValueError("DocumentSource requires path or url")
        path = source.path.resolve()
        if not path.is_file():
            raise FileNotFoundError(path)
        suffix = path.suffix.casefold()
        if suffix == ".pdf":
            metadata, pages = process_pdf(path, source)
        elif suffix == ".docx":
            metadata, pages = process_docx(path, source)
        elif suffix in {".md", ".markdown"}:
            metadata, pages = process_markdown(path, source)
        else:
            metadata = extract_metadata(path)
            pages = []
            if text_supports(path):
                pages = [ExtractedPage(page_number=1, text=extract_text(path))]
            elif ocr_supports(path):
                pages = [ExtractedPage(page_number=1, text=extract_ocr(path))]
        text = normalize_text("\n\n".join(page.text for page in pages))
        document = ProcessedDocument(source=source, metadata=metadata, pages=pages, text=text)
        document.chunks = chunk_text(text, document_id=document.document_id)
        document.citations = build_citations(document.document_id, pages, source_url=source.url)
        if generate_assets:
            document.preview_path = generate_preview(document, core_settings.document_preview_root)
            if ocr_supports(path):
                document.thumbnail_path = generate_thumbnail(path, core_settings.document_preview_root)
        index_document(document, self.search_index)
        bus.publish(DomainEvent("document.processed", {"document_id": document.document_id, "chunk_count": len(document.chunks), "citation_count": len(document.citations)}))
        metrics.increment("document.processed")
        metrics.increment(f"document.type.{suffix.lstrip('.') or 'unknown'}")
        return document

    def _process_url(self, source: DocumentSource) -> ProcessedDocument:
        parsed = parse_webpage(source.url)
        metadata = DocumentMetadata(name=source.name or parsed.title or source.url, extension="", mime_type="text/html", size_bytes=len(parsed.text.encode()), title=parsed.title, extra={"description": parsed.description, "canonical_url": parsed.canonical_url, "image_url": parsed.image_url, **parsed.metadata})
        pages = [ExtractedPage(page_number=1, title=parsed.title, text=parsed.text)]
        document = ProcessedDocument(source=source, metadata=metadata, pages=pages, text=parsed.text)
        document.chunks = chunk_text(parsed.text, document_id=document.document_id)
        document.citations = build_citations(document.document_id, pages, source_url=source.url)
        document.preview_path = generate_preview(document, core_settings.document_preview_root)
        index_document(document, self.search_index)
        bus.publish(DomainEvent("document.processed", {"document_id": document.document_id, "source_kind": "url", "chunk_count": len(document.chunks)}))
        metrics.increment("document.url_processed")
        return document


def process_document(source: DocumentSource, generate_assets: bool = True) -> ProcessedDocument:
    return DocumentEngine().process(source, generate_assets=generate_assets)
