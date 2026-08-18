# Module 6 — AI Assistant & Executive Agent

**Status:** Specification reviewed; implementation begins with an offline-first assistant command center and transparent local fallback.

## Purpose

Module 6 is the central productivity intelligence layer for FocusFlow. It is not a generic chatbot. It should understand workspace context, remember useful local context, search across supported domains, recommend actions, execute explicit commands, and explain each recommendation while keeping user data on-device unless the user explicitly exports or syncs it.

## First production slice

| Capability | Initial implementation |
|---|---|
| Assistant conversation | Persisted conversations and messages with role, timestamps, action metadata, and response reasoning |
| Offline fallback | Deterministic command router for overdue tasks, global keyword search, today's meetings, weekly planning, module navigation, and explicit task/note creation commands |
| Memory | Local memory items with scope, importance, source, confidence, pin/archive flags, and mutation queue; semantic embeddings remain an optional adapter |
| Workspace search | Search tasks, notes, and calendar events through normalized local projections; return source type, title, excerpt, and navigation target |
| Explainability | Every recommendation returns a human-readable reason and an action preview before destructive or ambiguous operations |
| Daily brief | Morning/evening brief endpoints derived from local tasks, events, notes, and focus metadata |
| Flutter UI | Responsive Assistant route with conversation history, command suggestions, markdown-like response cards, action chips, memory panel, and offline status |

## Domain and privacy boundaries

The assistant uses stable IDs from Tasks, Calendar, and Notes rather than duplicating those domains. Assistant messages, memory records, and action audit entries are append-only or versioned. The local fallback never requires Ollama, ChromaDB, Whisper.cpp, Piper, or paid APIs. Optional Ollama and future BGE/ChromaDB adapters consume the same request and result contracts without changing the UI or persistence layer.

Natural-language actions are intentionally scoped to deterministic, reviewable commands: create task, create note, show overdue tasks, find a workspace keyword, summarize today's meetings, plan the week, and open a FocusFlow module. Commands that could delete, archive, move, or bulk-edit content return an explanation and action preview rather than silently mutating data.

## API contracts

The FastAPI layer exposes assistant chat, command execution, conversation history, memory CRUD, workspace search, and daily brief endpoints under `/api/v1/assistant`. All responses carry `mode` (`local_rule` or `ollama`), `reasoning`, `sources`, and optional `actions` so the user can see what was considered and what will happen next.

## Acceptance baseline

The first delivery must function without a model or network, preserve conversation and memory offline, return useful cross-module search results, expose a visible Flutter Assistant route, pass backend and client tests, and deploy alongside the existing Dashboard, Smart Tasks, Calendar, Notes, and Express API routes. Voice, semantic vector search, long-term preference learning, broad tool execution, and full remote authentication remain subsequent increments connected through these contracts.
