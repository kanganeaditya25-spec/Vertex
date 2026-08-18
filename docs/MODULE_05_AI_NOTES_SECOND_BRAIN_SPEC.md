# Module 5 — AI Notes & Second Brain

**Status:** Three-part specification consolidated; implementation begins from the existing Module 4 calendar and Module 3 task foundations.

## Purpose

Module 5 turns FocusFlow notes into living knowledge rather than isolated documents. The system must support capture, organization, connection, retrieval, and understanding while remaining offline-first, privacy-first, and free of paid AI dependencies.

## Capability map

| Layer | Required capability | First production slice |
|---|---|---|
| Note domain | Rich note metadata, types, tags, folders, favorites, links, attachments, versions, history, soft deletion, sync status, knowledge scores | Normalized note model with block content, tags, links, version/history records, search metadata, and offline queue |
| Editor | Block-based writing, headings, paragraphs, lists, checklist, quote, callout, code, divider, toggle-ready structure, slash commands, auto-save, statistics | Responsive block editor with title, metadata, editable block list, add/duplicate/delete/reorder, slash-style insertion, checklist completion, and local auto-save |
| Knowledge experience | Backlinks, outgoing links, related notes, recent/favorites, global note search, filters, graph-ready link contracts | Searchable notes workspace with backlinks and related-note panels derived from local links |
| Advanced media | PDF annotation, voice recordings/transcription, whiteboard/drawing, Mermaid, LaTeX, embedded assets | Stable repository/service interfaces; advanced media remains an extension increment and is not represented by fake placeholders |
| Privacy and sync | Offline writes, version conflict detection, immutable history, optional encrypted storage, explicit sync/export only | SharedPreferences client persistence, FastAPI versioned contracts, mutation queue, and no hidden telemetry |

## Note model

Every note requires stable UUID identity, title, content and markdown content, summary, note type, tags, categories, folder/workspace/project links, linked task/event/goal/habit/asset identifiers, attachment references, color/icon, pinned/favorite/archive/delete flags, created/updated timestamps, version, author, AI-generated/encrypted flags, word count, reading time, language, sync status, knowledge score, importance score, and a future semantic embedding ID.

The first implementation stores editor content as an ordered list of typed blocks. This keeps each block independently movable, duplicable, deletable, convertible, collapsible, and linkable without tying the domain to one rich-text package. The server persists a canonical JSON representation and an indexed plain-text projection for fast local and API search.

## Knowledge links and history

Note links are bidirectional. Creating a link from one note to another must make the source outgoing link and target backlink discoverable. Links to tasks and calendar events use stable external IDs and do not duplicate those domains. Note history and note versions are append-only; restore creates a new version rather than deleting history. Deleted notes move to recoverable trash, and archived notes are read-only.

## Editor requirements

The editor follows Material 3 and MVVM/Riverpod boundaries with title field, metadata bar, block editor, formatting/insertion toolbar, AI action boundary, and save status. The core block types are paragraph, heading levels, quote, callout, divider, bullet/numbered list, checklist, toggle-ready block, code, and file/embed references. Slash commands are searchable commands such as `/text`, `/h1`, `/checklist`, `/code`, `/quote`, `/callout`, `/divider`, `/toggle`, `/date`, and `/time`.

Auto-save occurs after a typing pause, focus loss, navigation, or explicit save and must remain functional offline. The editor exposes word count, character count, paragraph/block count, headings, checklist progress, reading time, and a saved/saving/offline/error status. Keyboard and touch targets remain accessible, with reduced motion and high-contrast preferences respected.

## API and repository boundaries

The FastAPI layer should expose versioned note contracts for CRUD, archive/restore, version creation, history, linking/unlinking, search, export/import, recent, and favorites. Flutter uses NotesRepository, BlockEditorController, LinkRepository, HistoryRepository, and local search providers. Attachments reference the future Asset Library by ID instead of embedding a second asset system.

Every write persists locally and enters a queue record with note ID, operation, version, payload, attempts, and timestamps. API writes reject invalid content, orphan links, invalid version transitions, and edits to archived notes. No remote model is required for note creation or search; optional Ollama and future embeddings consume repository outputs through explicit service boundaries.

## Incremental acceptance baseline

The first delivery must establish a production-quality note domain, block editor, offline repository and queue, local search, tags, bidirectional note links, version/history, recent/favorite views, a usable responsive notes workspace, and tests. PDF, voice, whiteboard, Mermaid/LaTeX rendering, ChromaDB embeddings, semantic search, and full Asset Library integrations remain subsequent increments connected through these stable boundaries.
