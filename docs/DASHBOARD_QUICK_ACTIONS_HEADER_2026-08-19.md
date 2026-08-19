# Dashboard Quick Actions Header Migration

**Date:** 19 August 2026
**Phase:** Phase 3 — Product Stabilization & UX Overhaul
**Status:** Implemented, validated, and release-built; deployment pending

## Change summary

The Dashboard no longer renders a large Quick actions card inside the scrollable page body. The complete action set is now available from a dedicated bolt icon in the AppBar header under the accessible label **Quick actions**. This keeps the Dashboard focused on Today’s Mission, progress, focus mode, and meaningful work while preserving the existing destinations and callbacks.

## Preserved actions

| Action | Behavior |
|---|---|
| Quick capture | Opens the existing offline Quick Capture sheet |
| Start focus | Starts the existing local focus session |
| New task | Opens `/tasks` |
| Calendar | Opens `/calendar` |
| Notes | Opens `/notes` |
| Assistant | Opens `/assistant` |
| Projects | Opens `/organization` |
| Analytics | Opens `/analytics` |
| Automation | Opens `/automation` |
| Settings | Opens `/settings` |
| Assets | Opens `/assets` |
| Reminders | Opens `/reminders` |
| Command palette | Opens `/search?palette=1` |

The existing search, More destinations, notifications, and dashboard customization controls remain in the header. No gradients, decorative effects, or unrelated layout redesign were introduced.

## Validation

| Check | Result |
|---|---|
| Dart formatting | Passed |
| Flutter analysis | **No issues found** |
| Flutter tests | **46 passed** |
| Flutter web release build | Passed with existing non-blocking wasm/icon advisories |
| Public bundle preparation | Completed; rebuilt output copied into `public/` |

## Deployment acceptance

The final gate is to commit and push the Dashboard header migration, wait for the Vercel production deployment to report READY, and smoke-test the stable URL for HTTP 200 and the live `Quick actions` / action-label bundle markers.
