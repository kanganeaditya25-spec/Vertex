# FocusFlow V2 UX, UI, and Integration Audit

**Audit date:** 19 August 2026
**Method:** Static review of the current Flutter routes, providers, repositories, and shared Core Infrastructure, cross-checked against the product UX research notes in `docs/PRODUCT_UX_RESEARCH_FOCUSFLOW_V2.md`. This is an implementation audit, not a substitute for moderated user research or formal WCAG certification.

## Executive assessment

FocusFlow already has strong breadth: Tasks, Calendar, Notes, Assistant, Organization, Analytics, Automation, Settings, Assets, Reminders, Knowledge Graph, and Global Search exist as separate offline-first modules. The primary product risk is not missing surface area. It is **attention fragmentation**. The Dashboard exposes a large number of equal-weight navigation icons and widgets, while the default experience does not yet make the next meaningful action obvious or help the user recover from an overloaded plan.

The project model and event infrastructure are substantially stronger than the visible experience suggests. Tasks already carry project, workspace, and goal context; Organization tracks milestones and linked goals; the Knowledge Graph indexes cross-module entities; and the event bus provides synchronization boundaries. The redesign therefore focuses on exposing that existing context at the moment of work instead of introducing another disconnected module.

## Screen scores

Scores are directional static-audit scores from 1 (weak) to 5 (strong). They evaluate the current implementation’s ability to help a user complete meaningful work, not visual attractiveness.

| Screen | Usability | Cognitive load | Accessibility | Navigation | Motivation | Main finding | Priority |
|---|---:|---:|---:|---:|---:|---|---|
| Dashboard | 3 | 2 | 3 | 3 | 3 | Rich but admin-panel-like; no single mission or next action; too many app-bar destinations. | P0 |
| Tasks | 4 | 3 | 3 | 4 | 3 | Strong local workflow and filters; task context should be more visible and quick capture should be available from anywhere. | P0 |
| Calendar | 4 | 3 | 3 | 3 | 3 | Useful scheduling surface; needs clearer linkage between calendar commitments and the daily mission. | P1 |
| Organization / Projects | 3 | 3 | 3 | 3 | 3 | Hierarchy and project context exist, but progress and next work are not always surfaced in one compact view. | P0 |
| Notes | 4 | 3 | 3 | 3 | 3 | Good capture and knowledge foundation; needs clearer conversion from note to actionable task or study step. | P1 |
| Assistant | 3 | 3 | 3 | 3 | 3 | Local assistant is explainable; proactive recommendations should appear in context, not only after navigation. | P1 |
| Analytics | 4 | 3 | 3 | 3 | 3 | Metrics are available; the product should translate them into one next adjustment rather than more dashboards. | P1 |
| Automation | 3 | 3 | 3 | 3 | 3 | Powerful but advanced; templates and safe defaults should reduce setup effort. | P2 |
| Settings | 4 | 3 | 4 | 3 | 2 | Thorough and privacy-aware; keep it out of the primary work loop. | P2 |
| Assets | 3 | 3 | 3 | 3 | 3 | Central storage exists; task/project context should be visible when opening related assets. | P1 |
| Reminders | 4 | 3 | 3 | 3 | 3 | Strong lifecycle surface; avoid turning it into an unprioritized notification inbox. | P1 |
| Knowledge Graph | 3 | 3 | 3 | 3 | 3 | Relationship intelligence is valuable; expose only relevant context at task/project moments. | P1 |
| Global Search / Command Palette | 4 | 2 | 4 | 4 | 3 | Search and commands are available, but capture, focus, and actionable command paths should be first-class. | P0 |

## High-impact behavior problems

The Dashboard’s app bar currently contains many navigation actions, and its body renders overview, priority, focus, quick actions, calendar, notes, projects, habits, analytics, and AI insight widgets. This breadth makes the screen useful as a status board but less effective as a starting point for focused work. The redesign will preserve the data while changing the order of attention: **Today’s Mission → Start or continue focus → next actionable task → project progress and deadlines → supporting context**.

The current quick-action row includes navigation chips and a few inert-looking actions. A user who has a thought while working should be able to capture it immediately, then decide whether it is a task, note, reminder, project, or event. The redesign will add a real Quick Capture sheet backed by the existing TaskController for tasks and route-backed flows for the other entities, with no silent mutation and no placeholder actions.

The Project system already contains the required relationships in the local models, but the Dashboard project card is primarily a progress display. The redesign will make project cards actionable, show blocked status as a next-step cue, and carry project context into the Tasks route. This exposes the existing Project → Task relationship rather than inventing a second project model.

The motivation layer should reinforce meaningful completion rather than maximize interaction. The first implementation slice will therefore use completion feedback, mission progress, focus-time feedback, and recovery language for overloaded days. XP, streaks, and confetti are deliberately deferred until a behavior metric and opt-in preference are defined; adding them without guardrails would optimize engagement rather than meaningful work.

## Redesigned information architecture

The primary work loop becomes:

> **Capture → clarify → choose today’s mission → focus → complete → reflect → recover or plan the next step.**

The global navigation remains available through the existing routes and Command Palette, but the Dashboard becomes the default coach. Search remains the universal retrieval and navigation surface. Projects remain the context spine, while the Event Bus and shared Core Search remain the integration mechanisms.

## Implementation slice

| Change | User benefit | Existing contract reused |
|---|---|---|
| Today’s Mission card | Answers “What should I do right now?” without scanning the dashboard. | `DashboardSnapshot.tasks`, due dates, priority, estimate, goal title. |
| Overload / recovery guidance | Prevents unrealistic planning from becoming shame or abandonment. | Pending-task count and existing Tasks route. |
| Real Quick Capture sheet | Moves ideas out of working memory in seconds. | `TaskController.createTask`; existing routes for Notes, Reminders, Calendar, Assets, Organization. |
| Focus from the mission | Connects intention to a bounded work session. | `DashboardController.startFocus`. |
| Project cards with context actions | Makes progress actionable and preserves hierarchy. | `ProjectSummary.id`, existing `/tasks?project=...` route contract. |
| Dashboard hierarchy and semantic sections | Reduces equal-weight widgets and improves screen-reader traversal. | Existing widgets, renamed sections, `Semantics` labels. |
| Responsive navigation restraint | Prevents the app bar from becoming a row of competing destinations. | Existing routes and Command Palette. |

## Acceptance criteria for the redesign

The redesigned Dashboard must present one clear mission, provide a real start/continue action, keep capture within one interaction, expose project context on relevant work, and preserve an obvious path to Tasks, Calendar, Notes, Search, and Settings. All interactive controls require semantic labels, visible focus, minimum Material target sizing, and keyboard reachability. Reduced-motion preferences must not be violated by new motion. Empty states should explain the next useful action rather than only report absence.

The audit deliberately does not claim formal WCAG AA certification, measured 60 FPS performance, or validated behavioral lift. Those require automated accessibility tooling, device testing, performance profiling, and user research. This implementation slice creates testable foundations for those checks without overstating evidence.
