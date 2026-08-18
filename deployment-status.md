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
