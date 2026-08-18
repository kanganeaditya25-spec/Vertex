# Module 7 specification audit

## Current coverage

The existing release already provides the core offline-first hierarchy, workspace and project CRUD, goals, milestones, linked task IDs, linked notes, calendar-aware deadline views, templates, duplication, search, statistics, project intelligence, progress propagation, all seven project views, local SharedPreferences persistence, a mutation queue, and tested FastAPI contracts.

## Gaps identified against the attached specification

The release does not yet expose project/workspace export, richer project-dashboard integration counts for calendar and notes, asset/reminder link collections, dependency-conflict diagnostics, project-specific deterministic AI chat, a structured AI project-manager plan, search filters for status/category/goal, or explicit Flutter actions for edit, archive, duplicate, and delete. The UI also needs a more explicit connected-system representation and richer local project controls. Custom project statuses and future-ready collaboration metadata are not fully represented.

## Completion approach

The next patch will add additive organization fields and a safe SQLite schema upgrade path, deterministic project-manager planning and chat contracts, dependency diagnostics, export endpoints, richer dashboard integration summaries, filtered search, and offline Flutter CRUD/control surfaces. Networking, paid AI, external asset storage, and collaboration synchronization will remain outside the current scope as required by the specification.
