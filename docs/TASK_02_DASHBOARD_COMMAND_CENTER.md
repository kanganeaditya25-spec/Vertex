# Task 2 — AI Dashboard and Command Center

**Status:** Complete for Task 2 command-center scope — final Flutter web release commit `df2dbcf`
**Source:** User-provided Task 2 specification
**Application direction:** FocusFlow AI / Productivity Boost Dashboard

## Objective

Build the dashboard as the user’s productivity headquarters. It must answer **“What should I do right now?”** by combining today’s tasks, goals, deadlines, focus statistics, habits, calendar events, project status, recent notes, quick actions, and local AI readiness in one responsive Material 3 command center.

## Required dashboard areas

| Area | Required behavior | Implementation state |
|---|---|---|
| Smart greeting | Time-aware greeting, user name, date, and current goal. | Implemented in Flutter shell |
| Today overview | Remaining/completed tasks, events, focus time, and progress. | Implemented |
| Priority queue | Up to three tasks ordered by priority and deadline with an honest reason. | Implemented; local AI adapter is separate |
| Focus mode | Start, pause, resume, stop, elapsed time, today total, longest session, and distraction count field. | Implemented locally |
| Calendar preview | Today’s events and durations with empty state. | Implemented |
| Recent notes | Recent, pinned note summaries with empty state. | Implemented |
| Project status | Progress and blocked-state display. | Implemented |
| Habits | Completion and streak display. | Implemented |
| Analytics | Task completion, pending work, and focus chart. | Implemented with fl_chart |
| AI insights | Local Ollama readiness and graceful unavailable state. | Implemented as local boundary |
| Quick actions | Focus action works; future module actions are visibly non-destructive until their modules exist. | Implemented with honest action states |
| Customization | Show/hide widgets and reset layout through Riverpod state and local persistence. | Implemented |
| Offline storage | Snapshot and dashboard preferences persist locally through SharedPreferences. | Implemented |
| Responsive design | Single-column phone layout and two-column desktop/tablet layout. | Implemented |
| Accessibility | Semantic greeting, tooltips, labels, readable Material 3 controls. | Implemented in foundation |

## Domain boundaries

The dashboard is organized around `DashboardSnapshot`, `DashboardPreferences`, `DashboardRepository`, `DashboardController`, and the local `AiInsightService`. Future task, calendar, project, note, habit, notification, and search modules can feed the snapshot without redesigning the dashboard surface.

The Riverpod provider is the state boundary. The repository owns local serialization and preferences. The service boundary owns local AI availability and generation. The UI does not contain persistence or AI transport logic.

## Offline and privacy rules

The dashboard starts from an empty local snapshot when no saved data exists and remains usable without an internet connection. Ollama is optional; the UI reports that local AI is unavailable instead of fabricating an insight. No paid API, cloud AI service, external calendar, or remote notification provider is required for the command center.

## Acceptance tests

- Dashboard model JSON round-trip preserves tasks, goals, focus, and user name.
- Empty snapshot is valid for offline startup.
- FastAPI and local provider tests continue to pass.
- Focus controls update elapsed and daily focus state through Riverpod.
- Widget visibility changes persist through the dashboard repository.
- Phone and desktop layouts use one and two columns respectively.
- The dashboard exposes no secrets, JWTs, private tokens, or internal logs.
- Flutter analyzer and tests pass with the installed Flutter SDK; the release web build is published and verified on Vercel.

## Verification evidence

The deterministic Task 2 foundation verifier passed and confirmed the Flutter shell, required Riverpod provider names, repository persistence keys, local Ollama endpoints, dashboard sections, and absence of mock/placeholder markers in production Dart code. Flutter 3.47.0 and Dart 3.13.0 were then installed. `flutter analyze` reports no issues, `flutter test` passes both dashboard model tests, and `flutter build web --release` completes successfully. The Flutter web platform files were generated, and the resulting static assets were published through the existing Express `public/` directory.

The production deployment from the final web release commit `df2dbcf` is `READY` at Vercel.
The live root returns the Flutter HTML shell and `main.dart.js` returns HTTP 200. The existing Express `/api/auth/status` endpoint also returns HTTP 200, confirming that the API runtime remains available alongside the Flutter client.

## Explicit scope boundary

This task builds the dashboard command-center foundation and its real local state behavior. It does not yet implement every future module, the complete database repository set, or installed local AI models. The Flutter client now exposes an environment-overridable API base URL and an optional authenticated task/goal synchronization boundary, but it does not yet include the PIN login screen needed to obtain and persist a JWT. Until that auth flow is added, the deployed client intentionally remains offline-first and uses its local snapshot.
