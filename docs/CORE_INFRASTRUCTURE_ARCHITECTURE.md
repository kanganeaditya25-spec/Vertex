# Core Infrastructure & Document Engine Architecture

**Status:** Implemented and verified

**Date:** 19 August 2026

**Implementation commit:** [`ae14edb`](https://github.com/kanganeaditya25-spec/Vertex/commit/ae14edb)

**Implementation deployment:** `dpl_DV8YPyQx9QUuvLNuWcTDzVxHJtBh` — `READY`

**Final documentation deployment:** `dpl_292JUvPDttQLwsTtJsYkxfiqhKEY` — `READY`

**Final documentation commit:** [`3ae7657`](https://github.com/kanganeaditya25-spec/Vertex/commit/3ae7657)

## Purpose

This release establishes the shared infrastructure requested for FocusFlow AI. The backend now has a reusable `app.core` boundary for configuration, AI provider contracts, analytics, event delivery, search, storage, synchronization, security, notifications, and utilities. The document engine sits inside that boundary and provides processors for PDF, DOCX, Markdown, plain text/code, OCR, previews, thumbnails, metadata, URLs, web pages, citations, indexing, and semantic chunks.

The design deliberately keeps the infrastructure independent of the existing feature routers. Existing modules continue to own their domain models and API contracts, while shared services provide reusable capabilities. This avoids duplicating storage, search, OCR, and processing code as additional modules are added.

## Implemented package tree

```text
backend/app/core/
├── ai/
│   ├── contracts.py
│   └── engine.py
├── analytics/
│   └── metrics.py
├── configuration/
│   └── settings.py
├── event_bus/
│   └── bus.py
├── search/
│   └── index.py
├── storage/
│   └── service.py
├── sync/
│   └── queue.py
├── security/
│   └── service.py
├── notifications/
│   └── service.py
├── document_engine/
│   ├── contracts.py
│   ├── engine.py
│   ├── pdf_processor/processor.py
│   ├── docx_processor/processor.py
│   ├── markdown_processor/processor.py
│   ├── ocr_processor/processor.py
│   ├── preview_generator/processor.py
│   ├── thumbnail_generator/processor.py
│   ├── metadata_extractor/processor.py
│   ├── text_extractor/processor.py
│   ├── document_indexer/processor.py
│   ├── url_extractor/processor.py
│   ├── webpage_parser/processor.py
│   ├── citation_engine/processor.py
│   └── semantic_chunker/processor.py
├── logging/
│   └── service.py
├── performance/
│   └── service.py
└── utils/
    └── common.py
```

The Flutter client adds a typed facade at `frontend/lib/core/document_engine/`. It exposes document-processing results, search hits, capability discovery, and Dio-based calls to the shared backend contracts. Its failure behavior returns nullable or empty results so an offline-first screen can preserve local state when the Python service is unavailable.

## Processing pipeline

A file or URL enters through the Asset Library and is represented as a `DocumentSource`. The `DocumentEngine` selects a processor based on extension and source kind. PDF files use pypdf page extraction, DOCX files use python-docx paragraphs/tables and core properties, Markdown files are split by headings, plain text and code use bounded UTF-8 extraction, and images use Tesseract OCR. URL sources use the webpage parser to extract title, description, canonical URL, Open Graph image, and readable text.

The resulting pages are normalized into a `ProcessedDocument`. The engine generates bounded semantic chunks with offsets and token counts, page-level citations with locators and quotes, an HTML preview, and an image thumbnail when applicable. It then passes the document to the shared full-text index and emits a `document.processed` event. The default notification subscriber records a local “Document ready” notification, while metrics record processing counts. No external telemetry is introduced.

| Pipeline stage | Shared contract | Primary output |
|---|---|---|
| Source normalization | `DocumentSource` | Path, URL, MIME, source kind, Asset ID |
| Metadata extraction | `DocumentMetadata` | Hash, size, MIME, extension, properties |
| Text/page extraction | `ExtractedPage` | Page number, title, normalized text |
| OCR | Tesseract processor | Searchable text for image/scanned sources |
| Preview and thumbnail | Preview/thumbnail processors | Safe HTML preview and bounded WEBP thumbnail |
| Semantic chunking | `SemanticChunk` | Overlapping retrieval units with offsets |
| Citation generation | `Citation` | Page/source locator and quoted evidence |
| Indexing | `FullTextIndex` | Token-scored local search hits |
| Event and metrics | `DomainEvent`, `Metrics` | Decoupled status and runtime counters |

## Shared services

`LocalContentStore` provides atomic streamed writes, SHA-256 deduplication, hash-prefix directories, safe relative paths, and metadata-only references. `SyncQueue` provides ordered pending operations and acknowledgments for future server synchronization with thread-safe bounded retention. `EventBus` keeps processing, indexing, notifications, analytics, graph synchronization, and feature events decoupled; handler failures are isolated and reported. `NotificationCenter` keeps local status notices available without requiring push services and supports bounded retention, thread-safe read state, and domain-event subscribers. `Metrics` is an in-memory runtime counter and bounded timing surface rather than a telemetry collector. The Logging Engine emits structured redacted records, while the Performance Engine records bounded route timings through FastAPI middleware.

`FullTextIndex` performs deterministic token scoring, phrase boosts, snippets, and source metadata preservation. It is intentionally runtime-local in this release; the Asset Library database and Flutter SharedPreferences remain the source of truth for durable metadata. This keeps the first core release offline-safe while leaving a stable adapter boundary for SQLite FTS or another local index in a future module.

The security helpers enforce storage-root containment, PBKDF2-HMAC secret hashing, constant-time verification, safe filenames, and redacted values. The implementation does not add authentication bypasses, secret logging, or telemetry defaults.

## API contracts

The new shared API is registered under `/api/v1/core`:

| Route | Purpose |
|---|---|
| `GET /api/v1/core/capabilities` | Discover core services and document processors |
| `GET /api/v1/core/search?q=...` | Query the runtime full-text index |
| `GET /api/v1/core/metrics` | Read privacy-preserving in-process counters and timing averages |
| `GET /api/v1/core/notifications` | Read local processing notifications |
| `GET /api/v1/core/sync/pending` | Inspect pending sync operations |
| `POST /api/v1/core/sync/{operation_id}/ack` | Acknowledge a sync operation |

The Asset Library now also exposes `POST /api/v1/assets/{asset_id}/process`, which runs the shared engine, persists extracted preview/OCR text and processing metadata, records a version and sync event, and returns chunk/citation counts. Multipart uploads now use the shared streaming storage service instead of maintaining a second upload-write implementation.

## Verification

The full backend suite passed with **32 tests**. The Flutter suite passed with **17 tests**, and `flutter analyze` reported **No issues found**. Python bytecode compilation passed for `app` and `tests`. The release web build completed using the existing production API base URL and the rebuilt shell was copied into `public/`.

Vercel implementation deployment `dpl_DV8YPyQx9QUuvLNuWcTDzVxHJtBh` and final documentation deployment `dpl_292JUvPDttQLwsTtJsYkxfiqhKEY` both reached `READY`. The stable production root and `/assets` route both returned HTTP 200 with Flutter shell references. The current Vercel project serves the Express/Flutter shell; the Python FastAPI service remains independently runnable and tested under `/api/v1`. Reverse-proxying the Python service into the existing Vercel runtime is intentionally documented as a deployment follow-up rather than falsely represented as live.

## Core prompt implementation update

The original core layer was functional but incomplete against the full Core Infrastructure Prompt because Logging and Performance packages were absent and the AI package exposed contracts without a reusable provider registry. The current implementation adds `CoreLogger`, `redact_fields`, `PerformanceEngine`, `PerformanceMiddleware`, `AiEngine`, `RuleBasedAiProvider`, bounded metrics and notification/sync retention, event-handler fault isolation, expanded capabilities, notification acknowledgment, and workspace-aware shared search. These additions remain offline-safe and default to no external network dependency.

The current validation result is **46 FastAPI tests passed**, **27 Flutter tests passed**, clean Flutter analysis, and successful Python compilation. Final deployment identifiers are recorded after the current release build.

## References

- [1] [Vertex repository](https://github.com/kanganeaditya25-spec/Vertex)
- [2] [FocusFlow production deployment](https://vertex-eta-bice.vercel.app/)
- [3] [pypdf documentation](https://pypdf.readthedocs.io/)
- [4] [python-docx documentation](https://python-docx.readthedocs.io/)
- [5] [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
