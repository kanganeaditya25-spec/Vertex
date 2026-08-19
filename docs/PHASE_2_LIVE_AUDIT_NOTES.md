# Phase 2 Live Audit Notes

## Initial production check

On 19 August 2026, the live route `https://vertex-eta-bice.vercel.app/organization` returned HTTP-level Flutter shell content with page title `Productivity Dashboard`, but the connected browser extracted no rendered interactive elements or page content beyond the title after navigation and an additional wait/view. The browser screenshot upload failed, so this is recorded as a textual observation rather than a visual diagnosis. Further checks should determine whether the Flutter app is blocked by startup/runtime errors, stale service-worker assets, or a browser-specific rendering issue.

## Static findings already confirmed

The Flutter organization state cannot clear nullable `selectedProjectId` because `OrganizationState.copyWith` treats null as “keep existing value.” Switching to a workspace with no projects can therefore retain a project from the previous workspace. The same issue affects workspace creation, project archival, and project deletion.

The organization connected-systems card still routes the implemented Reminders module to `_showUnavailable` instead of `/reminders`.

The organization backend advertises project query routes such as `/tasks?project=<id>`, `/calendar?project=<id>`, `/notes?project=<id>`, and `/analytics?project=<id>`, but the Flutter router/pages currently do not parse or apply those query parameters. Task creation also does not expose project/workspace/goal assignment, despite the task model and organization model carrying related fields.

Baseline validation before repair: FastAPI `pytest` passed 36 tests; Flutter `analyze` reported no issues; Flutter `test` passed 20 tests.
