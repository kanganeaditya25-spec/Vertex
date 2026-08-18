# Task 7 — Workspaces, Projects, Goals, and Milestones

**Status:** Specification audit remediated, validated, and ready for redeployment.

## Implemented scope

Module 7 establishes the central FocusFlow organizational hierarchy: workspace → project → milestone → task → subtask. The FastAPI backend now provides workspace, project, goal, milestone, project-template, and sync-queue models with CRUD, archive, duplication, template instantiation, custom project statuses, budget and ownership metadata, asset and reminder link collections, project dashboards, statistics, filtered search, export contracts, progress calculation, deadline-risk analysis, dependency-conflict diagnostics, and explainable project-manager recommendations.

The project-scoped deterministic assistant supports summary, progress, blocker, risk, and milestone questions without a paid API or cloud model. The manager-plan contract returns estimated work, suggested milestones, next actions, blockers, and an explanation of the local inputs used. Project dashboards expose task, calendar, note, asset, reminder, goal, analytics, and assistant context through explicit connected-system counts and routes. An additive SQLite migration upgrades existing databases without deleting user data.

The Flutter client provides a responsive `/organization` route with a system-map sidebar, unlimited local workspaces, project and goal creation, milestone progress controls, connected goal context, project views for Dashboard, List, Kanban, Timeline, Calendar, Table, and Gallery, project duplicate/archive/delete controls, project-manager explanation, offline JSON-to-clipboard export, and connected navigation to Tasks, Calendar, Notes, Analytics, and Assistant. Data is persisted in SharedPreferences with a mutable local mutation queue. The visual system uses flat Material 3 cards, solid indigo, teal, amber, rose, blue, and violet accents, restrained status surfaces, and progress indicators. No gradients, decorative effects, or unrelated module redesigns were introduced.

## Verification

| Check | Result |
|---|---|
| FastAPI suite | **16 passed** |
| Flutter analyzer | **No issues found** |
| Flutter suite | **11 passed** |
| Flutter web build | **Succeeded** with the production API base URL |
| Published shell | `public/` replaced with the compiled Flutter release |
| Database upgrade | Additive migration is idempotent and preserves existing data |
| Existing routes | Preserved alongside `/organization` |
| Existing Express API | Preserved under `/api/*` |
| Whitespace validation | `git diff --check` passed before release commit |

## Scope boundary

The attached specification names future-ready integrations for Assets, Reminders, Automation, collaboration permissions, comments, and activity feeds. This release represents those modules through stable IDs, explicit routes, local integration cards, export metadata, and additive schema fields without inventing a second asset/reminder store or implementing networking. The architecture remains offline-first and free/open-source. Remote synchronization, multi-user collaboration, semantic search, and external file storage remain intentionally deferred until their dedicated modules expose stable contracts.

The full audit findings are recorded in `docs/MODULE_07_SPEC_AUDIT.md`.
