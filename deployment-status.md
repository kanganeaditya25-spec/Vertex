# Deployment status record

## Current public state

The deployed URL `https://vertex-eta-bice.vercel.app/` returns Vercel `500 INTERNAL_SERVER_ERROR` with code `FUNCTION_INVOCATION_FAILED`. The failure occurs on the root request before the dashboard loads.

The public error page exposes a request ID, but the linked Vercel logs redirect to the Vercel login page. Runtime logs therefore require the owner’s authenticated Vercel session.

## Likely local causes to verify

The application currently imports the experimental built-in `node:sqlite` module during serverless function initialization and opens a local SQLite file. Vercel’s serverless filesystem is ephemeral, and the deployment may also be using a Node runtime that does not expose `node:sqlite`. The server starts a scheduler and VAPID initialization at import/startup, which are also unsuitable for a serverless function and can cause initialization failures.

## Next actions

Verify the crash source from local source/runtime compatibility, adapt the server entry point for Vercel, prevent background scheduler startup in Vercel, and provide a durable external database path or clearly constrain the deployment to a non-persistent demo. Then commit, redeploy, and retest the public URL.

## Confirmed root cause from Vercel logs

The owner-provided Vercel log screenshot shows repeated `500` responses with `Error: ENOENT: no such file or directory, mkdir '/var/task/data'`. This confirms the crash occurs while the SQLite bootstrap attempts to create the local data directory inside Vercel's deployment bundle.

## Patch applied locally

The database path now uses `/tmp/productivity-dashboard/data` when `VERCEL=1`, while local development keeps `data/productivity.db`. Task attachments similarly use `/tmp/productivity-dashboard/uploads` on Vercel. The Express entrypoint now exports the app for serverless execution, and the local listener, VAPID initialization, and cron scheduler only start outside Vercel. The package now pins Node `22.x` for the built-in `node:sqlite` dependency.

A simulated Vercel-mode bootstrap passed: the exported Express app initialized and returned HTTP 200 for the PWA shell.

## Persistence limitation

The `/tmp` path is writable but ephemeral. This patch fixes the crash and makes the deployment runnable, but Vercel restarts or separate function instances may reset the SQLite database and uploaded files. Durable multi-instance use still requires migrating the database and file storage to external services.

## Redeployment result

Commit `e23e980` was pushed to `main`, which triggered the connected Vercel deployment. The public URL now returns HTTP 200 and loads the Productivity Dashboard PIN setup screen at `https://vertex-eta-bice.vercel.app/#login`. The previous `FUNCTION_INVOCATION_FAILED` crash is resolved.

Authenticated flows remain to be checked on the public instance. Creating a test PIN changes the deployed instance state, so confirmation is required before performing that write operation.

## Public authenticated-flow test

With user confirmation, a temporary test PIN `123456` was entered and submitted on the public Vercel login screen. The button entered a loading state; the result still needs to be checked.

The approved PIN setup completed successfully and redirected to `#dashboard`. The public dashboard loaded with authenticated navigation and zero-data metrics. The public Tasks page also loaded successfully, showing status filters, search, and New Task controls with an empty task state.

The public Personal Library page loaded with search, category filters, and Add Item. Reports & Goals loaded with Daily, Monthly, and Goals tabs, zero-data metrics, and the expected no-Gemini-key guidance. Both authenticated routes are functioning on Vercel.

The public Settings page loaded with reminder selectors, Gemini API key configuration, PIN controls, lock, and export. DOM verification confirmed the push notification toggle is inactive by default, with morning and evening reminders at 08:00 and 20:00.

## Task-goal feature verification

The backend task-goal smoke test passed: a linked task moved its goal from 0% to 100% and the goal status changed to completed; reopening the task reversed the goal to 0% and active. The local task page loaded, but the browser-rendered New Task modal did not yet show the Related Goal selector, so the frontend script source/cache needs to be checked before finalizing.

The local server serves the updated `tasks.js` with `Related Goal` and `goal_id`, but the browser’s fetched script remained an older cached copy. The discrepancy is caused by the existing service-worker/browser cache; it must be cleared or bypassed before judging the frontend change.

The cache-busted local UI now shows a Related Goal selector in the New Task modal, populated with the existing goal and helper text explaining automatic progress. The Goals tab shows `Link tasks to track this goal automatically` for goals without linked tasks, and the Dashboard shows the linked-task summary area while preserving existing cards and metrics.
