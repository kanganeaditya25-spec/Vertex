# Frontend Contrast and Authentication Fix

**Status:** Implemented, tested, and deployed.
**Date:** 19 August 2026
**Repository commit:** [`daf67cd`](https://github.com/kanganeaditya25-spec/Vertex/commit/daf67cdd9eb9922acaea4a77ffaa6675acff6083)
**Final frontend bundle:** Includes the follow-up Dashboard Sign out action and rebuilt public assets.

## Problem

The deployed Dashboard screenshot showed a dark surface with dark body and heading text. The root route also opened directly into the Dashboard, so there was no visible Login or Sign up entry point for a first-time user.

## Fix

The Flutter theme now derives text, display, scaffold, AppBar, and card colors from the active Material 3 color scheme. This prevents the previous forced-black typography palette from making text unreadable when the saved or system theme is dark.

The root route now uses an `AuthGatePage`. A user without a local session sees the Login/Sign up screen instead of being sent directly to the Dashboard. Explicit routes are available at `/login` and `/signup`. The screen also provides a clearly labeled **Continue offline as guest** path for users who want to start without creating an account.

The authentication store is offline-first and stores only a SHA-256 password hash and local session metadata in SharedPreferences. It does not send passwords to the backend and does not add telemetry. The Dashboard More destinations menu now includes **Sign out**, which clears the local session and returns the user to the authentication entry screen.

## Validation

| Check | Result |
|---|---|
| Flutter analysis | **No issues found** |
| Flutter tests | **36 passed** |
| Flutter release build | Successful |
| Production `/` | HTTP 200 |
| Production `/login` | HTTP 200 |
| Production `/signup` | HTTP 200 |
| Production `/search` | HTTP 200 |
| Production `/tasks` | HTTP 200 |
| Bundle markers | `Create local account`, `Continue offline as guest`, `Show password`, `Sign out`, and corrected Dashboard text present |
| Vercel deployment | `dpl_pngcHY9bEu1Q44nKJXaKfoy8pTYT` for `daf67cd` reported **READY** |

## Scope limitation

This fixes the missing frontend authentication experience as a privacy-first local/offline flow. It is not a multi-device server identity system. Durable server-side accounts, password recovery, email verification, OAuth, and cross-device session revocation require a separately deployed identity backend and should be implemented only as a later architecture milestone with secure server-side storage and recovery controls.
