# Task 9 — Automation Engine & Workflow Builder

**Status:** Implemented offline-first, validated, and ready for deployment.

## Implemented scope

Module 9 adds a no-code WHEN → IF → THEN automation system to FocusFlow AI. Workflows support one-time, scheduled, event-triggered, manual, recurring, conditional, and multi-step definitions. Each workflow stores a typed trigger, nested conditions with AND/OR/NOT support, ordered actions, variables, visual-builder nodes and edges, bounded retries, timeouts, maximum steps, and approval policy.

The FastAPI backend provides workflow CRUD, validation, template management, event emission, execution history, replay, statistics, natural-language workflow suggestions, and deterministic action execution. Supported local actions include task creation, task updates and archive/restore/delete state transitions, calendar-event creation, note creation, notifications, local summaries, subtasks/logical placeholders, data export logs, and safe integration placeholders for future Asset and Reminder modules. Destructive actions are paused for explicit approval. Validation rejects unsupported actions, invalid graph edges, circular node paths, missing terminal work, unsafe destructive approval configuration, and excessive step counts.

The Flutter client provides an `/automation` route with a flat Material 3 workflow workspace. It includes workflow selection, enabled/paused state, WHEN/IF/THEN representation, action-step controls, condition creation, local run controls, approval feedback, built-in templates, execution history, summary metrics, and offline SharedPreferences persistence. Local task actions write through the existing TaskRepository and its mutation queue. The UI uses solid indigo, teal, amber, blue, violet, and rose accents without gradients, decorative effects, or unrelated redesign changes.

## Verification

| Check | Result |
|---|---|
| FastAPI suite | **19 passed** |
| Flutter analyzer | **No issues found** |
| Flutter suite | **14 passed** |
| Flutter web release build | **Succeeded** with the production API base URL |
| Published shell | `public/` replaced with the compiled Flutter release |
| Offline task integration | Automation-created tasks persisted through the existing TaskRepository queue |
| Safety validation | Destructive actions require explicit approval; execution history records status and logs |
| Whitespace validation | `git diff --check` passed before release commit |

## Offline and hosting boundary

All user-visible automation execution works locally in the Flutter client. Event-triggered workflows run when the application emits a local module event; scheduled and recurring workflows are stored with schedule metadata and are evaluated while the application is active or resumes. This preserves the offline-first requirement without claiming 24/7 background execution from the current Express/Vercel shell. The FastAPI event and execution contracts are ready for a later persistent worker without requiring a workflow schema rewrite.

The first release intentionally does not invent duplicate Asset Library, Reminder Engine, Habit, Knowledge Graph, collaboration, or external webhook stores. Those action types are represented safely and logged until their dedicated modules expose stable local contracts. No paid API or cloud AI service is required; the workflow suggestion parser is deterministic and local.

## Documentation

The architecture and safety design are recorded in `docs/MODULE_09_AUTOMATION_ARCHITECTURE.md`. The final release preserves all prior module routes and the existing Express API surface.
