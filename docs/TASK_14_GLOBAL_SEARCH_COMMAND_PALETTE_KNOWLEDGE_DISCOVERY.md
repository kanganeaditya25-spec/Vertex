# Module 14 — Global Search, Command Palette & Knowledge Discovery

**Status:** Implemented, tested, committed, and deployed.
**Date:** 19 August 2026
**Repository:** [kanganeaditya25-spec/Vertex](https://github.com/kanganeaditya25-spec/Vertex)
**Production URL:** [https://vertex-eta-bice.vercel.app/](https://vertex-eta-bice.vercel.app/)
**Implementation commit:** [`e6a3a3d`](https://github.com/kanganeaditya25-spec/Vertex/commit/e6a3a3d49881fbd75b63efce52c9b1916c920ccd)
**Vercel deployment:** `dpl_9j2zhXF9qaCJg7gPCh6ApbaeE2ZV` — `READY`

## Purpose

Module 14 adds a unified, privacy-first discovery layer across FocusFlow AI. Users can search projects, goals, milestones, tasks, calendar events, notes, assets, reminders, workspaces, assistant context, and Knowledge Graph entities from one `/search` route. The same interface provides a command palette, natural-language intent normalization, deterministic semantic-style matching, fuzzy fallback, filters, smart collections, study-resource extraction, saved searches, history, discovery panels, and bounded knowledge paths.

The implementation remains offline-first and uses only the existing open-source Flutter, Riverpod, SharedPreferences, FastAPI, SQLAlchemy, and deterministic local algorithms. No paid API, cloud embedding provider, telemetry collector, or default network dependency was added.

## Implemented backend

The FastAPI search package is under `backend/app/search/` and contains persistent search-history, saved-search, smart-collection, and study-resource models; typed Pydantic contracts; workspace-aware indexing; multi-filter matching; intent parsing; deterministic semantic token scoring; fuzzy fallback; cached study extraction; command catalog execution; discovery; and knowledge-path contracts.

| Endpoint | Purpose |
|---|---|
| `POST /api/v1/search/query` | Search indexed entities with query, type, filters, pagination limit, and optional history recording |
| `GET /api/v1/search/query` | Query-compatible GET search contract for Module 16 integrations |
| `GET /api/v1/search/intent` | Normalize natural-language search intent into entity and filter hints |
| `GET /api/v1/search/history` | Read workspace-scoped recent search history |
| `POST /api/v1/search/saved` | Create or update a saved search |
| `GET /api/v1/search/saved` | List saved searches |
| `GET /api/v1/search/commands` | Return the command catalog |
| `GET /api/v1/search/commands/search` | Filter command catalog by user input |
| `POST /api/v1/search/commands/execute` | Execute safe navigation or create/focus command contracts |
| `GET /api/v1/search/discovery/{source_id}` | Return related items, forgotten items, missing links, and recommended collections |
| `POST /api/v1/search/study` | Extract summaries, concepts, definitions, formulas, dates, revision notes, cheat sheets, and questions |
| `GET /api/v1/search/collections` | Generate workspace-scoped smart collections |
| `POST /api/v1/search/knowledge-path` | Return a bounded knowledge path from the shared graph/search context |

Search hydration reuses Knowledge Graph nodes and the Core Search Engine. Graph nodes carry workspace, entity type, labels, content, tags, and metadata into the unified index. The service records only the explicit search-history feature; there is no implicit telemetry.

## Flutter implementation

The client adds search domain models, an offline `SearchRepository`, a Riverpod `SearchController`, and `GlobalSearchPage`. SharedPreferences stores locally indexed search documents, history, and saved queries. Matching combines token overlap, title weighting, metadata/tag filtering, and a bounded longest-common-subsequence fuzzy scorer. Study extraction is deterministic and includes summary, detailed summary, key concepts, definitions, formulas, important dates, revision notes, cheat-sheet terms, and review questions.

The `/search` route accepts `palette=1` and `workspace` query context. The Dashboard app bar now exposes **Open Global Search**, while **Ctrl+K** and **Cmd+K** open the Command Palette. The UI includes keyword, semantic-style, and AI-intent modes; source-type and recent filters; history; smart collections; result quick actions; study panels; discovery panels; and accessible result cards. Navigation continues to use existing module routes, preserving the current flat Material 3 visual system with solid accents, no gradients, and no decorative effects.

## Validation

The final validation gates passed as follows:

| Check | Result |
|---|---|
| FastAPI full regression | **52 passed** |
| Flutter full regression | **31 passed** |
| `flutter analyze` | **No issues found** |
| Flutter web release build | Completed successfully; only existing wasm dry-run and Material icon advisories were emitted |
| `git diff --check` | Passed before commit |
| Production `/search` route | HTTP **200** |
| Production bundle markers | Contains `Global Search`, `Command Palette`, and `Knowledge discovery` |
| Vercel deployment | `dpl_9j2zhXF9qaCJg7gPCh6ApbaeE2ZV` reported **READY** |
| Express compatibility | Existing Express shell and `/api/*` behavior preserved |

The new Flutter repository tests cover offline filtered search, history recording, saved-search persistence, study extraction, discovery, smart collections, and workspace isolation. The backend tests cover filtered search, natural-language intent, history, command execution, saved searches, cached study extraction, discovery, smart collections, and knowledge paths.

## Architecture limits and follow-ups

The current Vercel deployment still serves the Flutter static shell through Express, while the independently tested FastAPI service remains the `/api/v1` deployment surface described in the project status. Browser-local indexing and SharedPreferences persistence therefore provide the reliable offline experience; durable multi-device search history and saved-search synchronization remain dependent on the documented future database and storage deployment step.

The Module 14 semantic-style and AI-intent modes are deterministic local contracts rather than claims of cloud embedding inference. They are intentionally compatible with a future local Ollama, SQLite FTS, ChromaDB, or other open-source provider through the stable request and response schemas. Voice search remains represented by the existing local command surface; a native Whisper.cpp capture/transcription adapter can be connected through the same search command contract when a platform-specific audio pipeline is introduced, without changing the Module 14 search APIs.

## References

- [1] [Vertex repository](https://github.com/kanganeaditya25-spec/Vertex)
- [2] [FocusFlow production deployment](https://vertex-eta-bice.vercel.app/)
- [3] [Core Infrastructure architecture](CORE_INFRASTRUCTURE_ARCHITECTURE.md)
- [4] [Module 13 Knowledge Graph acceptance record](TASK_13_KNOWLEDGE_GRAPH_RELATIONSHIP_INTELLIGENCE.md)
