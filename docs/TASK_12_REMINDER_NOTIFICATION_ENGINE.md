# Module 12 — Reminder & Notification Engine

**Status:** Implemented, tested, committed, and published

**Acceptance date:** 19 August 2026

**Repository:** [kanganeaditya25-spec/Vertex](https://github.com/kanganeaditya25-spec/Vertex)

**Production route:** [https://vertex-eta-bice.vercel.app/reminders](https://vertex-eta-bice.vercel.app/reminders)

**Implementation commit:** [`2cc466d`](https://github.com/kanganeaditya25-spec/Vertex/commit/2cc466db18880b48810939bd99867203eb35bda6) — `Implement Module 12 Reminder & Notification Engine`

**Implementation deployment:** `dpl_2MUnaaZW8m9pExShBjoZ8A3Arias` — `READY`

**Acceptance-record commit:** [`d2e21b9`](https://github.com/kanganeaditya25-spec/Vertex/commit/d2e21b9a6b07bb4ae56f58555a381df89adf5400) — `Record Module 12 reminder notification acceptance`

**Final production deployment:** `dpl_4CdGGykW9u6iKr6L2zDurHEBAHgG` — `READY`, aliased to `vertex-eta-bice.vercel.app`

## Acceptance summary

Module 12 adds the FocusFlow Reminder Center and the supporting offline-first scheduling engine. Reminders are stable domain records rather than transient UI alerts, with typed lifecycle, recurrence, notification, quiet-hours, priority, history, and analytics contracts. The feature is available from the Dashboard app bar and quick actions, and the public Flutter bundle contains the Reminder Center route and UI.

The implementation uses only free and open-source technologies. Scheduling, recurrence, priority scoring, quiet-hour decisions, grouping, smart suggestions, and local persistence are deterministic and privacy-first. No paid AI API, telemetry, remote tracking, or cloud notification provider is required for the delivered slice.

## Supported reminder coverage

| Requirement | Delivered behavior |
|---|---|
| One-time reminders | Scheduled records with a single trigger timestamp and lifecycle actions |
| Recurring reminders | Daily, weekly, monthly, yearly, interval, count-limited, and custom recurrence contracts |
| Countdown and deadline behavior | Countdown metadata, due/overdue calculations, deadline trigger type, and priority escalation |
| Event-based reminders | Typed event ingestion for task completion, project start, asset processing, and automation workflow events; trigger types also cover task overdue, goal progress, calendar event, habit missed, asset review, AI suggestion, and project deadline |
| Follow-up reminders | Event adapters create explainable follow-up records from completed or started domain events |
| AI-suggested and smart reminders | Deterministic backend suggestion endpoint plus local explainable suggestions based on repeated snoozes and overdue high-priority work |
| Notification channels | Local, silent, critical, persistent, banner, and toast notification contracts; the Flutter client records and displays locally delivered alerts |
| Snooze | 5m, 10m, 15m, 30m, 1h, tomorrow, next week, and custom scheduling contracts; local history records every snooze |
| Lifecycle actions | Complete, snooze, reschedule, skip, archive, delete, duplicate, dismiss, and convert-to-task contracts; recurring completion schedules the next occurrence |
| Quiet and focus controls | Quiet hours, work hours, sleep schedule, focus-session, and calendar-awareness preference fields with critical-alert override behavior |
| AI priority engine | Explainable priority scoring using urgency, overdue state, recurrence, source, and criticality without requiring a hosted model |
| Bulk operations | Bulk complete, snooze, archive, dismiss, delete, skip, and reschedule contracts with selection support in Flutter |
| Search and grouping | Search across title, description, category, linked module, and source rule; grouping by date, category, priority, module, and trigger type |
| Notification center and history | Active, today, overdue, completed, dismissed, and history filters; immutable action history and delivered-alert count |
| Analytics | Active, overdue, due-today, completed, dismissed, snoozed, completion rate, average delay, priority breakdown, and source breakdown |
| Location-ready architecture | `location` trigger type and extensible location metadata are part of the typed contracts without requiring location access by default |

## Backend implementation

The backend implementation is contained in `backend/app/reminders/models.py`, `schemas.py`, `service.py`, `events.py`, and `backend/app/api/reminders.py`. The persistence classes are named `ReminderRecordModel`, `ReminderHistoryModel`, and `ReminderPreferenceModel` to avoid the existing calendar module's SQLAlchemy `ReminderModel` registry collision.

The API supports typed contract families for reminder CRUD, due scheduling, snooze, reschedule, complete-with-recurrence, bulk actions, grouping, statistics, smart suggestions, preferences, and event dispatch. `backend/app/api/tasks.py` publishes a `task.completed` domain event; `backend/app/main.py` registers the reminder router and event handlers while preserving the existing Express/Vercel shell architecture.

## Flutter implementation

The client implementation is contained in `frontend/lib/features/reminders/reminder_models.dart`, `reminder_providers.dart`, `reminder_worker.dart`, `reminders_page.dart`, and `frontend/lib/repositories/reminder_repository.dart`. The router registers `/reminders`; Dashboard navigation opens it directly; and `ReminderWorker` polls due records while the app is active, delivering through the local notification abstraction.

The Reminder Center provides responsive flat Material 3 cards, summary metrics, search, filters, smart suggestions, multi-selection, bulk actions, creation, completion, snooze, reschedule, and quiet-hour controls. The visual treatment remains restrained: solid semantic color containers, no gradients, no decorative effects, and keyboard- and screen-reader-compatible Material controls.

## Offline-first behavior

Reminder records, immutable action history, preferences, recurrence state, and local notification delivery state are stored through SharedPreferences under versioned module keys. Mutations update the local catalog immediately and are structured so a later authenticated synchronization layer can reconcile them without changing the domain model. `ReminderRepository.due()` applies quiet-hour suppression locally and permits critical notifications, preserving privacy and deterministic behavior when the backend is unavailable.

## Verification evidence

| Check | Result |
|---|---|
| `flutter analyze` | Passed — `No issues found!` |
| `flutter test` | Passed — 20 tests, including offline reminder persistence, recurrence, snooze history, and quiet-hour tests |
| `python3 -m pytest -q` from `backend/` | Passed — 36 tests; 3 pre-existing deprecation warnings only |
| Release web build | Passed — `flutter build web --release --dart-define=PRODUCTIVITY_API_BASE_URL=https://vertex-eta-bice.vercel.app/api` |
| Public shell synchronization | Passed — `frontend/build/web/` copied into `public/` |
| GitHub implementation push | Passed — commit [`2cc466d`](https://github.com/kanganeaditya25-spec/Vertex/commit/2cc466db18880b48810939bd99867203eb35bda6) |
| Vercel implementation deployment | Passed — `dpl_2MUnaaZW8m9pExShBjoZ8A3Arias` reported `READY` and matched commit `2cc466d` |
| Vercel final acceptance deployment | Passed — `dpl_4CdGGykW9u6iKr6L2zDurHEBAHgG` reported `READY` and matched commit `d2e21b9` |
| `/reminders` route | Passed — HTTP 200 with the Flutter shell |
| Root route | Passed — HTTP 200 |
| Live bundle content | Passed — bundle contains `Reminder Center`, `Smart suggestions`, `One place for every follow-up`, and `History` strings |
| Whitespace validation | Passed — `git diff --check` |

The Flutter build emitted non-blocking WebAssembly dry-run compatibility notices from existing dependencies and the existing Material icon-font notice. These did not prevent the standard analyzer, tests, release build, or production route from succeeding.

## Architectural notes and limitations

The current Vercel deployment serves the compiled Flutter shell through Express and retains the independently tested FastAPI service under `/api/v1`. The public route therefore demonstrates the production Flutter experience and offline behavior, while connecting the Python reminder API behind the existing Express deployment remains a deployment-architecture follow-up. The current Vercel filesystem is ephemeral, so durable multi-device reminder synchronization still requires an external database and storage layer.

The delivered local worker executes while the Flutter application is open or resumes. Vercel serverless execution is not claimed as a 24/7 scheduler. Browser notification permissions and platform-specific native notification capabilities remain user-controlled; the architecture exposes local notification channels and critical/persistent metadata without silently requesting permissions or sending data off-device.

No paid API is required. Telemetry remains disabled by default, all event payloads are typed and locally auditable, and the implementation preserves the existing Express prototype and legacy `/api/*` behavior.

## References

- [1] [Vertex GitHub repository](https://github.com/kanganeaditya25-spec/Vertex)
- [2] [FocusFlow Reminder Center](https://vertex-eta-bice.vercel.app/reminders)
- [3] [FastAPI reminders router](../backend/app/api/reminders.py)
- [4] [Flutter Reminder Center](../frontend/lib/features/reminders/reminders_page.dart)
