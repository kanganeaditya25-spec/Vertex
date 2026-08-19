# Calendar Date-Grid Upgrade — 2026-08-19

## User problem

The Calendar page did not present a visible date-oriented planning surface. The previous agenda/day/month implementation made it difficult to scan a week, see dates in columns, and understand when events were placed. Existing project-scoped filtering and offline persistence needed to remain intact.

## Delivered behavior

The Calendar now opens in a **Week** view. The weekly planner displays a Monday-to-Sunday date header, visible day numbers, previous/next week controls, a Today button, configurable work-hour rows, selected-day highlighting, and event chips placed in the correct day/time column. Tapping a date selects it, and tapping an event opens the existing details workflow.

The view switcher now offers **Week, Day, Month, and Agenda**. Day view retains date navigation and time intelligence. Month view retains date picking and selected-date events. Agenda remains available for list-based planning. Project-scoped URLs such as `/calendar?project={id}` continue to filter events by stable `projectId`.

Existing saved `agenda` preferences migrate to `week` so returning users see the new date-grid immediately. Explicit Day or Month preferences remain respected.

## Validation

| Check | Result |
|---|---|
| Flutter analysis | No issues found |
| Flutter suite | 41 tests passed |
| Calendar migration tests | Default week and agenda-to-week migration passed |
| Project context tests | Existing project-scoped calendar filtering passed |
| FastAPI suite | 52 passed |
| Flutter web release build | Successful |
| Production deployment | Pending final Vercel deployment smoke test |

## Scope and limitations

The Calendar remains offline-first and reuses the existing CalendarEvent, CalendarRepository, SharedPreferences queue, and project filter contracts. The weekly grid currently renders events by their start date and start-time slot; multi-day spanning events are retained in Day/Month/Agenda views and are not expanded across multiple weekly columns. This is documented rather than represented as a completed feature.
