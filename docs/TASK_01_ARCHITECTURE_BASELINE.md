# Task 1 — Free, Open-Source, Offline-First Architecture Baseline

**Status:** In progress
**Source:** User-provided Task 1 specification
**Project:** Productivity Boost Dashboard

## Objective

Establish the first implementation baseline for a production-ready AI productivity application that is free to operate, open-source, offline-first, self-hostable, cross-platform, modular, scalable, and suitable for commercial use.

## Required target stack

| Area | Required choice |
|---|---|
| Frontend | Flutter and Dart with Riverpod, Go Router, Material 3, Flutter Animate, fl_chart, local notifications, file/image/camera/PDF/Markdown support, and AppFlowy Editor where needed. |
| Backend | FastAPI on Python 3.13+, Uvicorn, Pydantic, SQLAlchemy, and Alembic. |
| Data | SQLite for development, PostgreSQL for production, with optional Redis only as a replaceable cache. |
| Authentication | JWT with refresh tokens, bcrypt password hashing, secure client storage, and optional free OAuth adapters. |
| AI | Ollama with local chat, coding, vision, and embedding models. No external AI API is required. |
| Retrieval and memory | ChromaDB with a local embedding model and LangChain or LlamaIndex only when retrieval adds clear value. |
| Speech and documents | Whisper.cpp, Piper or Coqui TTS, Tesseract OCR, PyMuPDF, and optional pdfplumber. |
| Storage | Local `/documents`, `/images`, `/audio`, and `/backups` directories with portable export and backup behavior. |
| Search | SQLite FTS5 or local ChromaDB semantic search. |
| Calendar and notifications | Internal calendar and Flutter local notifications; no required Google Calendar, Outlook, or Web Push dependency. |
| Testing | flutter_test, pytest, integration_test, API tests, and migration tests. |
| Delivery | GitHub, Docker, local server, self-hosted Linux, and free-tier deployment where it does not compromise data ownership. |

## Rules that must be enforced

1. The core application must not depend on paid APIs, subscriptions, hidden costs, or proprietary cloud services.
2. AI must work locally through Ollama and must degrade gracefully when a model is not installed.
3. Core productivity data must remain usable without an internet connection.
4. New domain logic must be separated from UI widgets, HTTP handlers, and a specific database implementation.
5. SQLite and PostgreSQL access must use a replaceable repository boundary.
6. New secrets, user data, local databases, model files, and generated backups must never be committed to Git.
7. Dependency licenses must be checked before adding packages intended for commercial distribution.
8. Each change must include validation, tests, documentation, and a reproducible migration or rollback path.

## Current implementation baseline

The repository currently contains a functioning Express.js and vanilla JavaScript web prototype with SQLite, PIN/JWT authentication, tasks, goals, reports, library items, local development scripts, and Vercel compatibility patches. The feature is valuable as a behavior reference, but it does not yet satisfy the target Flutter/FastAPI architecture. Flutter and Dart are not installed in the current environment, so Task 1 will establish the target structure and contracts without pretending that a Flutter build has been completed.

## Task 1 deliverables

| Deliverable | Acceptance condition | State |
|---|---|---|
| Architecture baseline | Target stack, rules, and current gap are documented. | Complete |
| Modular repository shape | Backend, frontend, data, services, providers, storage, AI, docs, and scripts boundaries are present or explicitly staged. | Complete |
| Backend foundation contract | FastAPI application boundary and health endpoint are defined without replacing the working prototype. | Complete |
| Frontend foundation contract | Flutter package and feature boundaries are defined without claiming an unavailable Flutter build. | Complete |
| Local AI boundary | Provider interface and Ollama integration point are documented as an optional local adapter. | Complete |
| Quality gates | Task 1 validation and evidence are recorded in this document and `PROJECT_STATUS.md`. | Complete |
| Git history | Task 1 changes are committed and pushed to GitHub. | Pending |

## Explicit non-goals for Task 1

Task 1 does not yet migrate the complete web application, install large AI models, provision PostgreSQL or ChromaDB, build every Flutter screen, or remove the existing prototype. Those activities are later tasks and must use the architecture and workflow defined here.

## Verification evidence

The FastAPI foundation passed `python3 -m compileall -q backend` and `python3 -m pytest -q backend/tests` with three passing tests. The tested contract returns HTTP 200 for `/` and `/api/v1/health`, reports the service name and environment, and includes an ISO timestamp. The Flutter SDK is not installed in the current environment, so `flutter analyze` and `flutter test` remain pending and are explicitly not claimed as complete.

The staged foundation is ready for review and commit. Full Flutter build verification, persistence repositories, authentication, and data migration remain later tasks.
