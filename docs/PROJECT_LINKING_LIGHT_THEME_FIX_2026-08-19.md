# Project Linking and Light Theme Repair — 2026-08-19

## Problem

The Organization page displayed project task counts from `ProjectModel.linkedTaskIds`, while the Task repository persisted project context only on `TaskModel.project`. Because those two stores were independent, tasks created from a project could appear in the project-filtered Tasks screen without appearing in the project’s visible linked-task count or project dashboard.

The deployed presentation also remained dark when a persisted prior theme preference was present. The dark palette made hierarchy and secondary labels difficult to read in the project workspace.

## Changes

The offline task repository now synchronizes project linked-task IDs on task creation, update, project moves, deletion, and startup reconciliation. Existing stale project metadata is repaired from the task records. Duplicated projects preserve their linked-task list. The Organization page now derives its live task count from `TaskController`, shows a **Tasks linked to {project}** section with real task titles/statuses, and provides an explicit **Open tasks** action scoped to the project.

The Flutter application now uses a light-only Material 3 baseline with a soft neutral background, white cards, thin neutral borders, readable foreground colors, restrained teal/indigo accents, no gradients, and no decorative effects. Existing settings data cannot reintroduce the previous dark presentation in this release.

## Validation

| Check | Result |
|---|---|
| Flutter analysis | No issues found |
| Flutter suite | 39 tests passed |
| Project-link regression | Creation, move, deletion, and stale-link repair passed |
| FastAPI suite | 52 passed |
| Flutter web release build | Successful |
| Release bundle | Contains `Tasks linked to` marker |
| Production deployment | Pending final Vercel deployment smoke test |

## Scope note

The repair is offline-first and preserves the existing API and module boundaries. It does not add a new server-side relationship schema because the current Flutter persistence model is the source of truth for local task/project workflow. Server synchronization remains represented by the existing queues and API contracts.
