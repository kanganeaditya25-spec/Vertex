# Productivity Boost Dashboard — Project Status

**Last updated:** 18 August 2026
**Repository:** [kanganeaditya25-spec/Vertex](https://github.com/kanganeaditya25-spec/Vertex)
**Public deployment:** [https://vertex-eta-bice.vercel.app/](https://vertex-eta-bice.vercel.app/)
**Current branch:** `main`
**Latest deployed fix commit:** `e23e980` — `Fix Vercel serverless filesystem crash`

## Executive summary

The Productivity Boost Dashboard is now deployed on Vercel and the original serverless crash has been fixed. The public URL returns the dashboard PIN setup screen instead of Vercel’s `FUNCTION_INVOCATION_FAILED` page. The authenticated dashboard, Tasks, Personal Library, Reports & Goals, and Settings sections have been verified in the public deployment.

The application is currently usable as a Vercel demo. Its remaining architectural limitation is data durability: the app still uses SQLite and local file attachments, while Vercel function storage is ephemeral. Data written during one function instance may not be available after a restart, redeploy, or instance change. A durable production release still requires an external database and external file storage.

## What has been completed

| Area | Status | Details |
|---|---|---|
| Express backend | Complete | Existing API routes for authentication, tasks, library, goals, reports, notifications, and settings are deployed. |
| Vanilla PWA frontend | Complete | Dashboard shell, navigation, manifest, service worker, responsive layout, and page modules load publicly. |
| PIN security | Complete for current demo instance | Temporary test PIN `123456` was created with user confirmation and the public dashboard unlocked successfully. |
| Task management | Verified | Public Tasks page loads with filters, search, and task creation controls. |
| Personal Library | Verified | Public Library page loads with filters, search, and Add Item controls. |
| Reports & Goals | Verified | Daily, Monthly, and Goals tabs load; no-Gemini-key fallback guidance renders correctly. |
| Settings | Verified | Reminder controls, Gemini key field, PIN controls, lock, and export are available. Notifications are off by default. |
| Vercel deployment | Complete | Public root, manifest, service worker, and auth-status endpoint all return HTTP 200. |
| Project record | Complete | This document and `deployment-status.md` record the diagnosis, patches, verification, and limitations. |

## Original failure and confirmed cause

The public site originally returned:

> `500: INTERNAL_SERVER_ERROR` — `FUNCTION_INVOCATION_FAILED`

The owner-provided Vercel logs showed the exact initialization error:

> `Error: ENOENT: no such file or directory, mkdir '/var/task/data'`

The database bootstrap attempted to create a SQLite data directory inside Vercel’s deployment bundle. That location is not writable during serverless execution. The application also started local-only background services during server startup, which are not appropriate for the Vercel function lifecycle.

## Fixes applied

The database bootstrap now uses the local `data/productivity.db` path during normal development and `/tmp/productivity-dashboard/data` when `VERCEL=1`. Task attachments use the equivalent `/tmp/productivity-dashboard/uploads` path on Vercel. These temporary paths prevent the crash but do not provide durable persistence.

The Express entrypoint now exports the app for Vercel. The local HTTP listener, VAPID initialization, and cron scheduler only start outside Vercel. The package configuration pins Node.js to `22.x`, which is required by the current built-in `node:sqlite` implementation.

A Vercel-mode bootstrap test was added at `scripts/vercel-bootstrap-test.js`. It imports the server with `VERCEL=1`, serves the PWA shell, and passed with HTTP 200 before redeployment.

## Verification record

The following public checks passed after commit `e23e980` was deployed:

| Check | Result |
|---|---|
| Public root URL | HTTP 200; dashboard PIN setup screen rendered. |
| PIN setup | Temporary PIN was created after user confirmation; redirect to `#dashboard` succeeded. |
| Dashboard | Authenticated dashboard rendered with zero-data metrics and navigation. |
| Tasks | Authenticated Tasks page rendered with filters, search, and New Task controls. |
| Personal Library | Authenticated Library page rendered with filters, search, and Add Item controls. |
| Reports & Goals | Daily, Monthly, and Goals tabs rendered with no-Gemini fallback guidance. |
| Settings | Settings rendered; notification toggle was inactive by default; reminder selectors showed 08:00 and 20:00. |
| Static PWA assets | `/manifest.json` and `/sw.js` returned HTTP 200. |
| Public auth status | `/api/auth/status` returned HTTP 200 with `{"isSetup":true}`. |

## Current limitations

Vercel’s serverless filesystem is ephemeral. The `/tmp` SQLite database and `/tmp` attachment directory are writable, but they may be cleared when the function restarts or when requests are served by another instance. This means the current deployment should be treated as a demo or single-instance experiment, not as a durable multi-user production service.

The background reminder scheduler is disabled in Vercel mode because a cron process cannot reliably remain alive inside a request-scoped serverless function. Push notifications also require stable VAPID configuration and durable subscription storage before they can be considered production-ready.

The Gemini API key is intentionally not configured in the deployment. A user can enter a key through Settings, but with the current ephemeral SQLite storage that configuration is not durable.

## Recommended next phase

For a durable release, migrate the SQLite tables to a hosted database compatible with Vercel, such as a managed Postgres or hosted SQLite provider, and move attachment storage to object storage. Store `JWT_SECRET`, Gemini credentials, VAPID keys, and database credentials as Vercel environment variables. Replace the local cron scheduler with a supported scheduled invocation or external job runner, then repeat the authenticated end-to-end tests.

## Commit history relevant to this work

| Commit | Description |
|---|---|
| `49a341e` | Initial full-stack dashboard implementation. |
| `58d58a8` | Notification settings, scheduler behavior, validation, and API smoke tests. |
| `e23e980` | Vercel serverless filesystem crash fix, Node runtime pin, deployment record, and bootstrap test. |

## References

[1]: https://vercel.com/docs/frameworks/backend/express "Express on Vercel — Vercel Documentation"
[2]: https://vercel.com/kb/guide/is-sqlite-supported-in-vercel "Is SQLite supported in Vercel? — Vercel Knowledge Base"
[3]: https://render.com/docs/free "Deploy for Free — Render Documentation"

## Task–goal connection feature

**Status:** Implemented and verified locally.

Tasks now have an optional `goal_id` link. The task modal includes a simple Related Goal selector populated from existing goals, and task cards show the linked goal title when present. The database performs a backward-compatible migration for existing installations.

When a linked task is completed, the related goal progress is calculated as:

> completed linked tasks ÷ total linked tasks × 100

A goal with all linked tasks completed is automatically marked completed. Reopening a linked task recalculates the goal and returns it to active status. Removing a task or moving it to another goal also recalculates the affected goal. Goals without linked tasks continue to support the existing manual progress field.

The Dashboard now shows linked-task completion context beneath Active Goals, and each goal card displays its linked-task completion count. The Goals report includes the same linked-task totals so the existing interface remains simple but more informative.

The local regression suite passed the Vercel bootstrap test, settings/auth API smoke test, and task-goal smoke test. The task-goal test confirmed the full sequence `0% → 100% → 0%` as a linked task was completed and reopened. The cache-busted browser check confirmed the Related Goal selector, Goals report text, and Dashboard summary render correctly.

The feature is committed and pushed in commit `e45949c`, and the public Vercel bundle contains the new task-goal UI. The existing Vercel persistence limitation remains unchanged: linked data uses the current SQLite storage model until an external durable database is added. After redeployment, the ephemeral instance returned to PIN setup and reset the prior demo data.

## Frontend cache reliability fix

A browser check showed the deployed task modal still rendering an older version without Related Goal, even though the public bundle contained the new feature. The cause was the previous cache-first service worker returning stale JavaScript. Frontend assets now use version query parameters, service-worker registration is versioned, the cache name is bumped to `productivity-dashboard-v2`, and online fetches use a network-first strategy with offline fallback. This ensures users receive the current task-goal UI after the deployment refresh.

## Enhancement workflow adopted

The project now follows `docs/ENHANCEMENT_WORKFLOW.md`, based on the attached free, open-source, offline-first architecture standard. Future enhancements must pass architecture compliance, domain/data design, backend and client implementation, offline behavior, local-AI, security, testing, documentation, and deployment gates.

The target architecture is Flutter plus Riverpod on the client, FastAPI plus SQLAlchemy/Alembic on the backend, SQLite for development, PostgreSQL for durable production, Ollama for local AI, ChromaDB for optional semantic memory, and local notifications and file storage. The existing Express web application remains the working prototype while migration is performed incrementally rather than through a disruptive rewrite.

## Task 1 — architecture foundation

**Status:** Foundation implemented; commit pending.

Task 1 established the first staged foundation for the user-provided free, open-source, offline-first architecture. The repository now contains a FastAPI backend boundary with a versioned `/api/v1/health` contract, Python package metadata, a SQLAlchemy/Alembic-ready session boundary, a Flutter package manifest, a Material 3 + Riverpod + Go Router client shell, backend and frontend runbooks, and a Task 1 acceptance record at `docs/TASK_01_ARCHITECTURE_BASELINE.md`.

The existing Express web prototype remains intact and continues to serve as the behavior reference. Flutter and Dart are not installed in the current environment, so Flutter build verification is explicitly pending rather than being claimed. The FastAPI foundation passed compilation and two health endpoint tests. Later tasks will add repositories, authentication, migrations, local Ollama providers, offline storage, and the remaining cross-platform features.

Task 1 also now includes a local Ollama provider adapter with a graceful offline-unavailable error and a deterministic fallback test. The backend foundation test suite passes three tests. Flutter analysis remains pending because the sandbox does not contain the Flutter SDK; this limitation is explicitly recorded in the Task 1 acceptance document.

Task 1 is now complete as a staged architecture foundation. The implementation was pushed in commits `8c91343` (`Establish offline first app foundation`) and `2ed2ccd` (`Ignore generated development artifacts`). Three backend tests pass, including the FastAPI health contract and Ollama-unavailable fallback. Flutter build verification remains pending because Flutter/Dart are not installed in the current sandbox; this is recorded explicitly and is not treated as a failed or falsely completed check.
