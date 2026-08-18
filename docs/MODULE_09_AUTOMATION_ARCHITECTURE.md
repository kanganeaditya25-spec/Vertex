# Module 9 — Automation Engine architecture

## Execution model

Module 9 uses a deterministic offline-first event engine. Workflows are persisted as JSON-compatible records in SQLite on the FastAPI side and SharedPreferences on the Flutter side. A manual action, local module mutation, or application-resume tick can emit an event. The engine evaluates the matching enabled workflows, applies nested conditions, executes approved actions, and records an immutable execution history.

The design is intentionally local. It does not require a paid API, cloud model, external webhook, or always-on server. Recurring and scheduled workflows are evaluated when the application is active or resumes, which preserves offline behavior and avoids silently claiming 24/7 execution while the public runtime remains the existing Express/Vercel shell. A later persistent worker can consume the same event and queue contracts without changing the workflow schema.

## Core contracts

| Contract | Purpose |
|---|---|
| Workflow | Name, type, enabled state, trigger, conditions, actions, variables, retry and approval policy |
| Trigger | Event type plus optional schedule and payload filters |
| Condition | Field, operator, value, and nested AND/OR/NOT groups |
| Action | Typed deterministic operation with parameters, order, retry count, and approval requirement |
| Execution | Success, failure, pending approval, duration, action logs, error, and replay linkage |
| Template | Reusable workflow definition for daily planning, review, kickoff, study, deadlines, meetings, notes, and habits |
| Event queue | Offline event payload with attempts, processed time, and replay-safe identity |

## Safety

Destructive actions such as delete, bulk delete, workspace deletion, and asset deletion are never executed silently. The engine marks them as pending approval unless an explicit approved run is supplied. Workflow validation rejects unsupported action types, circular node references, unsafe loop limits, and workflows with no terminal action. Every run has a maximum step count, bounded retries, and a structured log.

## Integration boundary

The first release integrates task creation/update/archive, local notifications, calendar event creation, note creation, project and goal context variables, analytics score variables, exports, and deterministic AI-summary placeholders. Asset, reminder, habit, knowledge-graph, and external collaboration actions are represented as stable action types and logged safely until their dedicated modules expose durable local stores. The visual builder uses flat Material 3 surfaces and solid accent colors only; it does not use gradients or decorative effects.
