# FocusFlow Achievement and Reward System

**Date:** 19 August 2026
**Phase:** Phase 3 — Product Stabilization & UX Overhaul
**Status:** Implemented and release-built; deployment pending the acceptance commit

## Purpose

FocusFlow now provides behavior-focused completion feedback without turning productivity into a game. The system recognizes meaningful task completion through a small set of explainable signals: XP earned from completed work, consecutive-day streaks, best streak, active completion days, level progress, and a limited set of trophies. The presentation is intentionally calm and subordinate to the Dashboard’s Today’s Mission so it reinforces consistent work rather than encouraging compulsive engagement.

## Implemented scope

| Area | Implementation | Persistence |
|---|---|---|
| Domain model | `AchievementProfile`, `TrophyDefinition`, five stable trophy definitions, calendar-date helper | JSON-compatible model |
| XP and levels | 25 XP per unique completed task; level starts at 1 and advances every 100 XP | SharedPreferences |
| Duplicate protection | Completed task IDs prevent re-awarding XP when the same task is toggled or reconciled repeatedly | SharedPreferences |
| Streaks | Consecutive calendar-day logic with normalized dates, current streak, best streak, and active completion-day count | SharedPreferences |
| Trophies | First Step, Steady Week, Momentum Builder, Focused Month, and Deep Practice | SharedPreferences |
| State integration | Riverpod `AsyncNotifier` loads and refreshes the profile; task completion records the event after the task mutation succeeds | Offline-first |
| UI | Dashboard card with FocusFlow brand mark, streak, XP, trophies, completed count, level, progress bar, and earned titles | Flutter Material 3 |

The completion event is emitted only when a task transitions from incomplete to completed. Reopening a task does not award XP. The repository stores date-only completion values for streak calculations, so task completion at different times of day does not create false streak breaks.

## Trophy definitions

| Trophy | Meaning | Threshold |
|---|---|---:|
| First Step | Complete the first meaningful task | 1 task |
| Steady Week | Maintain a three-day completion streak | 3 consecutive days |
| Momentum Builder | Complete meaningful work consistently | 10 tasks |
| Focused Month | Complete work on distinct days | 15 days |
| Deep Practice | Reach sustained completion momentum | 500 XP |

These thresholds are local, deterministic, and transparent. There are no leaderboards, social comparisons, confetti, paid APIs, telemetry, or remote tracking.

## Accessibility and UX decisions

The card uses existing Material 3 color-scheme roles, solid surfaces, readable text, semantic labels, and a linear progress indicator. It does not use gradients, animation-heavy reward effects, decorative imagery, or urgency language. On narrow screens, metrics wrap instead of forcing horizontal overflow. The FocusFlow mark is a reusable vector-style widget built from Material primitives and has compact and full variants.

## Validation record

| Check | Result |
|---|---|
| Dart formatting | Passed on all changed achievement, dashboard, task, repository, and test files |
| Flutter static analysis | **No issues found** |
| Flutter tests | **44 passed** |
| FastAPI regression suite | **52 passed**, 3 existing deprecation warnings |
| Flutter web release build | Passed with existing non-blocking wasm dry-run and Material icon advisories |
| Public bundle preparation | Completed by replacing `public/` with the release output |

The regression tests cover XP awarding, duplicate-completion protection, streaks across different completion times, trophy unlock behavior, and stable trophy definitions. The existing Express API backend remains untouched and continues to serve `/api/*`; the achievement profile is intentionally local and offline-first.

## Deployment acceptance gate

The release bundle must be committed to `main`, pushed to [kanganeaditya25-spec/Vertex](https://github.com/kanganeaditya25-spec/Vertex), and allowed to complete the Vercel deployment. After deployment, smoke checks must confirm HTTP 200 for the root route and that the served bundle contains the strings `Progress you can feel`, `Streak`, `XP`, `Trophies`, and `FocusFlow`.

This milestone does not close Phase 3. It is an additional stabilization slice. Module 16 remains paused until the Phase 3 exit record confirms that stabilization and integration gates are complete.
