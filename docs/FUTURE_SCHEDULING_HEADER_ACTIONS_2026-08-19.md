# Future Scheduling and Header Quick Actions

**Date:** 19 August 2026
**Phase:** Phase 3 — Product Stabilization & UX Overhaul
**Status:** Implemented, validated, and release-built; deployment pending

## Problem addressed

New tasks and calendar events were being created with current-day defaults and the creation dialogs did not provide a date/time selector. This made it difficult to schedule work four or five days ahead. Creation controls were also duplicated as floating actions or in-body buttons across several pages, increasing visual competition and reducing header consistency.

## Implemented behavior

| Area | Change |
|---|---|
| Tasks | Task creation now includes an optional date/time picker and persists the selected value as `TaskModel.deadline`. Dates can be selected up to ten years ahead. |
| Calendar events | Event creation now includes an optional date/time picker, preserves the selected day/time, and defaults to the current calendar selection when available. |
| Quick Capture | Task, Reminder, and Calendar capture now share an optional future date/time selector. Selected dates flow into task deadlines, reminder triggers, and event start times. |
| Calendar navigation | Existing week/day/month navigation remains intact; selecting future dates continues to change the visible date context and future events remain stored by their actual date. |
| Header actions | New Task, New Event, New Note, and New Reminder actions are in the relevant AppBar headers. Duplicate floating actions were removed from Tasks, Calendar, Notes, and Reminders. |
| Visual direction | The light minimalist Material 3 theme, solid accents, restrained spacing, and offline-first persistence are preserved. |

## Validation

| Check | Result |
|---|---|
| Dart formatting | Passed |
| Flutter analysis | **No issues found** |
| Flutter tests | **46 passed** |
| FastAPI regression suite | **52 passed**, with 3 existing deprecation warnings |
| Future task serialization test | Passed; deadline remains five days ahead with time preserved |
| Future event serialization test | Passed; event date/time and duration remain unchanged |
| Header-action static check | Passed; no floating action controls remain on Tasks, Calendar, Notes, or Reminders |
| Flutter web release build | Passed with existing non-blocking wasm/icon advisories |

## Deployment gate

The release bundle has been synchronized to `public/`. The next step is to commit and push the implementation, wait for the Vercel production deployment to report READY, and smoke-test the stable URL for HTTP 200 and the new scheduling/header strings.

Module 16 remains paused until Phase 3 stabilization exit is explicitly recorded.
