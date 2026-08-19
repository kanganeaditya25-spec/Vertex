# Module 13 — Knowledge Graph & Relationship Intelligence

**Status:** Implemented locally, tested, and ready for production release build.  
**Date:** 19 August 2026  
**Repository:** [Vertex](https://github.com/kanganeaditya25-spec/Vertex)

## Purpose

Module 13 creates a centralized, offline-first graph over FocusFlow AI entities. Nodes represent projects, goals, milestones, tasks, calendar events, notes, assets, reminders, workspaces, and assistant context. Directed relationships preserve source and target semantics while the context APIs expose incoming links, outgoing links, related nodes, suggested connections, and explainable paths.

The implementation uses the existing SQLAlchemy SQLite service for backend persistence and SharedPreferences for the Flutter offline client. It does not introduce a paid graph database, external semantic API, telemetry collector, or network dependency.

## Implemented backend

The backend package is under `backend/app/graph/` and contains persistent `GraphNodeModel`, `GraphRelationshipModel`, and `GraphSuggestionModel` tables; typed Pydantic contracts; deterministic relationship scoring; workspace isolation; backlinks; path search; duplicate detection; orphan and connected-item insights; graph density and connected-component analytics; and event-bus synchronization.

The graph service reuses the shared Core Search Engine. Every upserted graph node is indexed with its entity type, workspace, label, text, and tags. Graph event handlers listen to entity lifecycle and relationship events. Existing project, milestone, and task event payloads can therefore update the graph without feature modules duplicating graph persistence logic.

| Endpoint | Purpose |
|---|---|
| `POST /api/v1/graph/nodes` | Create or update a graph node |
| `GET /api/v1/graph/nodes` | Workspace-scoped node listing and filtering |
| `POST /api/v1/graph/relationships` | Create or update a directed relationship |
| `GET /api/v1/graph/relationships` | Relationship table and node backlinks |
| `GET /api/v1/graph/context/{node_id}` | Incoming, outgoing, related, and suggested context |
| `GET /api/v1/graph/search` | Entity search across graph content and tags |
| `GET /api/v1/graph/path/{source}/{target}` | Bounded breadth-first knowledge-path search |
| `GET /api/v1/graph/stats` | Nodes, relationships, density, components, orphans, accepted suggestions |
| `GET /api/v1/graph/suggestions` | Explainable deterministic relationship suggestions |
| `POST /api/v1/graph/suggestions/{id}/accept` | Convert a suggestion into an AI-sourced relationship |
| `GET /api/v1/graph/insights` | Most-connected, orphaned, and missing-relationship insights |
| `GET /api/v1/graph/duplicates` | Duplicate and similar-content candidates without destructive merge |

## Relationship intelligence

The offline scorer combines shared tags, shared project/goal/topic metadata, and token-set similarity. Recommendations always include an explanation, such as shared tags or a measured proportion of shared content terms. The engine never claims to have used an external model. A user must accept a suggestion before it becomes a relationship, and accepted suggestions are counted in graph analytics.

Duplicate detection checks content hashes, normalized labels, and high token-set similarity. It only recommends review; it never deletes or merges user data automatically.

## Flutter implementation

The client adds `GraphNodeModel`, `GraphRelationshipModel`, `GraphSuggestionModel`, `GraphStatsModel`, and `GraphInsightModel` under `frontend/lib/features/knowledge_graph/`. `GraphRepository` persists nodes, links, suggestions, relationship degrees, and view state inputs through SharedPreferences. `GraphController` provides Riverpod state for workspace filtering, search, view switching, node selection, relationship creation/removal, suggestion generation, acceptance, dismissal, path-capable repository operations, and insight refresh.

`KnowledgeGraphPage` is available at `/knowledge-graph` and from the Dashboard app bar and Organization Project connected-systems panel. It includes an accessible search field, statistics, network view with pan and zoom, tree/mind-map/hierarchy grouping, timeline view, relationship table, explainable suggestion actions, graph insights, and an expanded selected-node context/backlink panel. The UI uses the existing flat Material 3 system with restrained solid accents, no gradients, no decorative effects, and no telemetry.

## Validation

Backend acceptance tests cover graph CRUD, workspace isolation, relationship degree maintenance, path search, search integration, suggestions, acceptance, duplicate detection, insights, event-bus synchronization, capability discovery, performance, logging redaction, notification acknowledgment, and sync/event safety. Flutter tests cover offline persistence, relationship paths, suggestion acceptance, duplicates, and workspace isolation.

The current validation result is **46 FastAPI tests passed**, **27 Flutter tests passed**, **No issues found** from `flutter analyze`, Python compilation passed, and all graph routes are covered by API-level tests. Production release build completed successfully. Vercel deployment `dpl_CQR9wQ4tXNP6xpRLT8eSSU3V7P3g` for commit [`73d84f9`](https://github.com/kanganeaditya25-spec/Vertex/commit/73d84f9) reached `READY` and aliased `https://vertex-eta-bice.vercel.app`. Live HTTP checks returned `200` for `/`, `/organization`, `/knowledge-graph`, and `/knowledge-graph?workspace=workspace-1`; the deployed bundle contains the Knowledge Explorer, graph insights, suggested connections, and Dashboard navigation strings.

## Capacity and limits

The graph uses indexed SQLite tables and bounded API responses rather than claiming that a single-process release has already proven the prompt’s aspirational 1,000,000-node and 5,000,000-relationship targets. Queries are workspace-scoped, path depth is bounded, API list limits are capped, and the Flutter network canvas renders a bounded visible slice while the table and grouped views provide lazy-friendly alternatives. A future scale release can replace the repository adapter with SQLite FTS/graph extensions or a dedicated local graph store without changing the API contracts.

## References

- [1] [Vertex repository](https://github.com/kanganeaditya25-spec/Vertex)
- [2] [FocusFlow production deployment](https://vertex-eta-bice.vercel.app/)
- [3] User-provided Module 13 Knowledge Graph & Relationship Intelligence prompt (`pasted_content_20.txt`)
