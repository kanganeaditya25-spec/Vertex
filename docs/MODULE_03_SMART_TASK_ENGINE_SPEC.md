# Module 3 — Smart Task Management Engine

**Status:** Specification consolidated; implementation begins from the existing Task 2 foundation.

## Purpose

Module 3 turns the FocusFlow dashboard into an intelligent, offline-first task management engine. The system must treat tasks as rich domain objects rather than simple title/status records, while preserving the existing Flutter + Riverpod + GoRouter client, FastAPI backend boundary, local persistence, and Ollama-based AI boundary.

The three supplied specification parts define one coherent module with four layers:

| Layer | Required capability | Initial implementation boundary |
|---|---|---|
| Task domain | Rich tasks, subtasks, checklists, tags, dependencies, reminders, recurrence, attachments, comments, history, templates, archive/restore, bulk actions, import/export | Establish a normalized task domain and implement the highest-value offline operations first |
| Task workspace UI | Search, smart filters, summaries, compact task cards, details, focus mode, list/board/calendar-ready views, multi-select, responsive and accessible interaction | Add a dedicated Task Home and Task Details flow without disrupting the deployed dashboard |
| Intelligence | Rule-based priority/risk scores, explanations, breakdown, estimates, goal alignment, scheduling, daily planning, reviews, burnout and focus recommendations | Implement deterministic local intelligence first; call Ollama only through a graceful optional boundary |
| Sync and privacy | Offline writes, queueing, versioning, conflict detection/resolution, local AI, no hidden tracking, optional encrypted backup path | Build repository and sync contracts that remain usable with no network or model |

## Domain requirements

A task must support stable UUID identity, title and description, configurable status and priority, category/project/workspace relationships, tags, subtasks, checklist items, attachments, comments, history, dependencies, estimated and actual effort, deadline/reminders, recurrence, location, energy, difficulty, importance, AI/risk scores, progress, parent/child relationships, archive/delete timestamps, sync metadata, color/icon, pinned/favorite/hidden/private/shared flags, and AI-generated provenance.

The status model must be configurable and include Inbox, Today, Upcoming, Scheduled, Waiting, In Progress, Blocked, Completed, Cancelled, Archived, and Deleted. Priority must support Critical, Urgent, High, Medium, Low, optional Someday, and a dynamic AI priority. Energy and difficulty are first-class fields because later recommendation logic depends on them.

Subtasks must support nesting, independent completion, progress calculation, reordering, and conversion between a subtask and a normal task. Checklists must support nested items, reordering, progress, and completion history. Dependencies must support finish-to-start, start-to-start, finish-to-finish, and start-to-finish relationships, with cycle detection and automatic blocked-state derivation.

## Offline and business rules

All task operations must work offline and enter a durable sync queue. Every mutable record requires version, created/updated timestamps, soft-delete state, and sync status. Completed tasks cannot be edited without reopening. Blocked tasks cannot start until dependencies are satisfied. Archived tasks are read-only. Deleted tasks remain recoverable for 30 days. Recurring tasks create the next occurrence only after completion. Subtask and checklist progress update the parent task automatically. History is append-only and immutable.

## Intelligence requirements

The local intelligence layer must calculate priority, risk, importance, urgency, and confidence with transparent explanations. Inputs include deadline, estimated effort, dependencies, project and goal alignment, workload, energy, overdue status, calendar conflicts, and historical behavior. The first fallback must be deterministic rule-based logic; local Ollama models are optional and must never be required for the app to function.

The architecture must leave clear service boundaries for task breakdown, time estimation, scheduling, daily planning, evening review, goal alignment, deadline prediction, burnout detection, focus recommendations, smart notifications, semantic search, related-task discovery, smart categorization, tagging, productivity scoring, habit learning, and natural-language commands. ChromaDB, local embeddings, Whisper.cpp, and Piper remain optional local integrations and must not become runtime prerequisites for the initial web build.

## UI requirements

The Task Home screen should provide an app bar, persistent search, horizontal smart filters, today summary, a compact but informative task list, and an AI action entry point. Task cards should show completion, priority, title, deadline, category, tags, effort, progress, reminder, attachments, subtasks, project, and AI score. Interactions should support opening details, selection mode, complete/archive swipe actions where platform-appropriate, drag reorder, quick actions, and responsive layouts.

The Task Details flow should use collapsible Overview, Description, Checklist, Subtasks, Attachments, Comments, History, Dependencies, Activity Timeline, AI Insights, Related Tasks, and Suggested Next Steps sections. The implementation must preserve accessibility, keyboard navigation on desktop, semantic labels, high contrast, large text, reduced motion where possible, and clear empty/loading/error/offline states.

Future-ready view boundaries include Kanban, calendar, timeline, list density, and table views. They should be introduced through view-model and repository contracts rather than by coupling the core task model to one layout.

## Data and API boundaries

The FastAPI layer should expose versioned task contracts for CRUD, archive/restore, complete, duplicate, move, split/merge, history, search, filter/sort, attachments, comments, and statistics. The Flutter layer should use feature-first MVVM/repository boundaries with Riverpod providers for task list, selected task, filters, sort, search, reminders, categories, tags, history, statistics, and sync.

The existing Express API remains the deployed compatibility layer during migration. The Flutter client must remain able to start from local data and may synchronize with the deployed API only after an authenticated token is available. No new implementation may require a paid cloud AI service.

## Acceptance baseline

Module 3 is accepted incrementally. The first delivery must establish a production-quality rich task domain, offline repository and sync queue contracts, deterministic priority/risk explanations, task list/detail UI, and tests. Later increments may add the remaining views and local AI integrations without redesigning these boundaries. Production code must contain no TODOs, mock implementations, or placeholder UI.
