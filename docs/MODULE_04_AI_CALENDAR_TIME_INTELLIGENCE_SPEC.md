# Module 4 — AI Calendar & Time Intelligence

**Status:** Four-part specification consolidated; implementation begins from the existing Module 3 task engine.

## Purpose

Module 4 transforms the calendar from a date display into an offline-first time manager that answers **what should I do next, when should I work, how long should I work, and whether the schedule is feasible**. The system must remain useful without internet access or a local model, use transparent deterministic fallbacks, and never overwrite a user’s schedule without confirmation.

## Capability map

| Layer | Required capability | First production slice |
|---|---|---|
| Event domain | Rich events, all-day and multi-day support, recurrence, buffers, links to tasks/goals/projects, reminders, notes, history, archive/delete, versions, sync status | Normalized event model with validated time ranges, recurrence metadata, task/goal links, history, and sync queue |
| Calendar workspace | Day, week, month, agenda, planner, timeline, split view, responsive interaction, search, filters, quick add, event details | Responsive calendar workspace with month/agenda/day planning views, search/filter, quick add, and event details |
| Time intelligence | Slot selection, priority/deadline/effort/energy matching, conflict detection, workload analysis, focus blocks, breaks, buffers, deadline risk, explainable recommendations | Deterministic local scheduler, conflict detector, workload and risk summaries, and accepted/rejected recommendation records |
| Personalization | Working hours, energy profile, first day of week, view preference, density, colors, reduced motion, accessibility, sidebar/widgets | SharedPreferences-backed calendar preferences and accessible Material 3 controls |
| AI boundary | Ollama models, embeddings, ChromaDB, Whisper.cpp, Piper, daily plan, weekly review, learning engine | Stable service interfaces and rule-based fallback; Ollama remains optional and no cloud API is required |

## Event model

Every event requires stable UUID identity, title and description, category/type, priority, status, start and end timestamps, timezone, duration, location and optional coordinates, reminder and recurrence metadata, color/icon, linked task/project/goal identifiers, notes, estimated and actual duration, focus type, energy requirement, travel/preparation/cleanup buffers, AI-scheduled and locked/flexible flags, recurring and completion state, timestamps, soft-delete/archive timestamps, version, and sync status.

The supported event types include Meeting, Task Block, Focus Block, Deep Work, Break, Exercise, Study, Travel, Sleep, Meal, and Custom. The architecture must support unlimited user-defined categories and independent colors. Locked events cannot move; flexible events may move. Deleting one recurrence instance must not delete the entire series unless explicitly requested.

## Scheduling and intelligence rules

The deterministic scheduler must consider priority, deadline, estimated duration, dependencies, energy, focus requirement, availability, commitments, importance, goal alignment, workload, working hours, personal preferences, and buffers. It must generate a schedule with a human-readable explanation. Deep work should prefer high-energy periods, meetings medium-energy periods, and light tasks low-energy periods. The engine must propose—not silently apply—dynamic rescheduling.

The first rule-based fallback must support deadline risk, completion probability, remaining effort, feasible hours, overloaded days, overlap/double-booking, missing buffers, missing breaks, dependency conflicts, focus block recommendations, break planning, daily workload balancing, and supportive burnout signals. Recommendations should be records with accepted/rejected/edited outcomes so later local learning can use explicit user feedback.

## UI and accessibility requirements

The calendar workspace follows Material 3 with responsive phone, tablet, desktop, and wide layouts, light/dark themes, high contrast, reduced motion, semantic labels, accessible tooltips, keyboard navigation, touch targets of at least 48dp, and WCAG AA-oriented contrast. It should provide app-bar date context, search, notification and sync status, AI/fallback status, settings, mini calendar navigation, jump-to-today/date, view switching, filters, quick actions, clear empty/error/offline states, and collapsible event details.

The initial UI should prioritize practical views rather than pretending every future view is complete. Day and agenda planning are the primary interactions; month view provides navigation and event density; week/planner/timeline/split view contracts remain extensible. Event cards should surface title, category, priority, time, duration, location, linked task, energy, AI/risk badge, and completion state. State changes use subtle Flutter animations under 250ms where practical, while reduced-motion preferences disable nonessential motion.

## Persistence and API boundaries

The FastAPI layer should expose versioned calendar contracts for event CRUD, duplicate, archive, restore, today/week/month/agenda queries, reminders, templates, statistics, scheduling recommendations, conflicts, workload, daily plans, and recommendation feedback. The Flutter layer should use Riverpod providers and repository/service boundaries for selected date, view state, event collection, filters, reminders, conflicts, schedule, focus blocks, preferences, statistics, and sync.

All writes must work offline, persist locally, and enter a durable queue with event ID, operation, version, payload, attempt count, and timestamps. Every edit is recorded in immutable history. Sync must support version checks and conflict detection without data loss. The current Express deployment remains the compatibility layer while the new FastAPI calendar API is developed and tested in the repository.

## Privacy and performance

Schedule data must stay on-device unless the user explicitly exports or syncs it. No telemetry, advertising, hidden analytics, or paid APIs are allowed. The system should be designed for lazy loading and indexed queries, with target budgets of under 500ms for month view, under 300ms for agenda, under 200ms for conflict/search operations, and under one second for deterministic daily schedule generation on normal local datasets.

## Incremental acceptance baseline

The first delivery must establish a production-quality event domain, offline repository and queue, deterministic scheduling/conflict services, calendar API contracts, and a usable responsive calendar workspace with day/agenda/month planning. Future increments may add the remaining advanced views, external/local media integrations, full recurrence editor, attachments, participants, ChromaDB memory, speech, and authenticated remote synchronization without redesigning the core boundaries.
