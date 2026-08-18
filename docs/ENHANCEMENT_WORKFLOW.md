# Productivity Boost Dashboard
## Enhancement Workflow and Target Architecture

**Status:** Adopted as the project development standard
**Date:** 18 August 2026
**Repository:** [kanganeaditya25-spec/Vertex](https://github.com/kanganeaditya25-spec/Vertex)

## 1. Purpose

This document defines the workflow that must be followed for every future enhancement to the Productivity Boost Dashboard. The project will move toward a **free, open-source, offline-first, self-hostable, modular, and commercially usable architecture**. The attached technology standard supplied for this project is the source of truth for architectural direction and technology selection.

Every new feature must preserve the product’s core purpose: helping users manage tasks, goals, resources, reminders, and productivity insights with a simple interface and reliable local operation.

## 2. Non-negotiable engineering principles

| Principle | Required interpretation |
|---|---|
| Free operation | Do not require paid APIs, subscriptions, usage-based services, or hidden hosted costs. |
| Open source | Prefer open-source libraries and runtimes. Check licenses before adding dependencies, especially for commercial distribution. |
| Offline-first | Core task, goal, calendar, search, reminders, analytics, files, and AI workflows must remain usable without internet access. |
| Self-hostable | The complete system must be runnable on a local computer or self-managed Linux/Docker host without a proprietary platform. |
| No vendor lock-in | External services may not be required for core functionality. Data must remain exportable in standard formats. |
| Privacy by default | Keep user data local whenever possible. Do not send private content to paid or external AI providers. |
| Modular design | Separate presentation, API, data access, domain logic, AI providers, storage, and background work. |
| Cross-platform direction | The target client is Flutter for Android, iOS, Web, Windows, macOS, and Linux. |
| Simple UX | Enhancements should add useful information and automation without creating unnecessary screens or configuration. |
| Testable delivery | Every enhancement must include automated checks appropriate to its backend, client, and integration surface. |

## 3. Target architecture

| Layer | Target technology | Responsibility |
|---|---|---|
| Client | Flutter and Dart | Cross-platform user interface and offline-first interaction. |
| State and navigation | Riverpod and Go Router | State management, dependency injection, and route control. |
| UI | Material 3, Flutter Animate, fl_chart | Accessible interface, restrained animation, and productivity analytics. |
| Local client storage | Hive, SharedPreferences, flutter_secure_storage | Preferences, offline cache, secure tokens, and local settings. |
| Backend | FastAPI, Python 3.13+, Uvicorn | API, authentication, domain services, file operations, and orchestration. |
| Validation and persistence | Pydantic, SQLAlchemy, Alembic | Request validation, database access, and repeatable migrations. |
| Database | SQLite for development; PostgreSQL for production | Local development and durable self-hosted production storage. |
| Semantic memory | ChromaDB with local embeddings | Private semantic search and AI memory. |
| Local AI runtime | Ollama | Local chat and analysis models with no API keys or usage limits. |
| Speech | Whisper.cpp and Piper or Coqui TTS | Offline speech-to-text and text-to-speech. |
| OCR and documents | Tesseract OCR and PyMuPDF | Local image/PDF text extraction and document processing. |
| Files | `/documents`, `/images`, `/audio`, `/backups` | User-controlled local file storage and portable backups. |
| Search | SQLite FTS5 or ChromaDB | Fast local keyword search and optional semantic search. |
| Notifications | Flutter local notifications | Offline reminders without Web Push dependency. |
| Delivery | Docker, local server, self-hosted Linux, or free-tier infrastructure | Reproducible deployment without dependence on one vendor. |

## 4. Current state and migration position

The current deployed application is a working web prototype built with Express.js, vanilla HTML/CSS/JavaScript, SQLite, PIN/JWT authentication, Web Push support, and an optional Gemini integration. It is useful for validating product behavior, but it does not yet satisfy the target architecture because it is not Flutter/FastAPI-based, uses a hosted AI API option, and relies on ephemeral SQLite storage when deployed to Vercel.

The project will therefore use a **phased migration rather than a disruptive rewrite**. Existing web functionality remains available while new domain logic is extracted into modular services. New enhancements must follow the target rules even when implemented temporarily in the existing web client. Migration work will replace non-compliant components in priority order.

| Current component | Target direction | Migration priority |
|---|---|---:|
| Express routes and JavaScript domain logic | FastAPI routes with Python service and repository layers | High |
| Vanilla web client | Flutter client using Riverpod and Go Router | High |
| SQLite on Vercel ephemeral storage | PostgreSQL or self-hosted persistent SQLite | High |
| Optional Google Gemini API | Ollama with a selectable local model | High |
| Web Push and server scheduler | Flutter local notifications and platform background work | Medium |
| Local task/library files | Structured local storage directories with backup/export rules | Medium |
| Basic text reports | Ollama analysis plus ChromaDB semantic memory | Medium |
| Existing JSON export | Portable backup format retained and expanded | High |

## 5. Required enhancement workflow

Every enhancement must pass through the following sequence. Work must not skip directly from an idea to implementation.

### Step 1 — Define the user problem

Write a short problem statement, identify the user flow being improved, and define the smallest useful outcome. Explain how the change improves task management, goals, resources, reminders, analytics, or AI assistance.

### Step 2 — Check architecture compliance

Before selecting a dependency or API, confirm that it is free, open-source or appropriately licensed, self-hostable, offline-compatible, and not a hidden vendor dependency. Paid APIs and cloud-only AI services are prohibited for core functionality. The preferred AI path is a local Ollama provider.

### Step 3 — Design the domain and data model

Define entities, relationships, validation rules, migration requirements, and backup behavior before editing UI code. Keep domain logic independent of Flutter widgets, HTTP handlers, or a specific database driver.

### Step 4 — Implement the backend and repository layer

Implement the domain service, repository methods, validation, authorization, and database migration first. Use FastAPI, Pydantic, SQLAlchemy, and Alembic for the target architecture. While the legacy web backend remains active, changes must be isolated so they can be migrated cleanly.

### Step 5 — Implement the client experience

Add the smallest clear interface using Flutter, Riverpod, Go Router, and Material 3 for new target-architecture work. Keep the existing web client aligned during the migration period when the feature is still exposed there. Do not introduce duplicate business rules in the UI.

### Step 6 — Add offline behavior

Decide what happens with no network connection. Core actions must be stored locally, queued, or completed locally. Synchronization, if later added, must be conflict-aware and must never make local data inaccessible.

### Step 7 — Add local AI only where valuable

Use Ollama for local text analysis, planning suggestions, goal summaries, and classification. Use ChromaDB and a local embedding model only when semantic memory or retrieval provides a clear benefit. AI must degrade gracefully when models are not installed.

### Step 8 — Secure the feature

Use bcrypt for passwords, JWT access and refresh tokens, secure storage on clients, HTTPS for remote access, strict input validation, and least-privilege file handling. Never commit secrets, API keys, local databases, model files, or private user data.

### Step 9 — Test the enhancement

At minimum, add the appropriate unit, API, integration, and UI checks. Test normal behavior, invalid input, empty state, offline behavior, authentication, data migration, and recovery from missing optional AI models.

### Step 10 — Document and deliver

Update the project status record, architecture notes, migration notes, and user-facing instructions. Run formatting and security checks, commit with a focused message, push to GitHub, and verify the relevant local or self-hosted deployment.

## 6. Definition of done

An enhancement is complete only when all applicable conditions below are satisfied:

- The user problem and acceptance criteria are documented.
- The feature uses the approved architecture or has an explicit migration note.
- No paid API or cloud-only dependency is required for the core flow.
- The feature remains usable offline or has a documented offline fallback.
- Data changes include a migration and preserve existing data.
- Authentication, authorization, validation, and file handling are tested.
- Automated tests pass, including regression checks for affected features.
- The project-status document records what changed and what remains.
- The change is committed to GitHub with a focused commit message.
- The relevant deployment or self-hosted runtime is verified.

## 7. Prohibited dependencies and patterns

The project must not introduce OpenAI API, Anthropic API, Google Gemini API, Claude API, Azure OpenAI, Pinecone, Weaviate Cloud, Supabase AI, Firebase AI, AWS Bedrock, Hugging Face Inference API, ElevenLabs API, AssemblyAI API, or another paid SaaS dependency for core functionality. Cloud services may be used only as optional adapters when the application remains fully functional without them and the adapter is clearly isolated.

The project must also avoid putting business logic inside UI widgets, storing secrets in source control, requiring Google or Outlook calendars for basic calendar behavior, making cloud AI mandatory, or using a hosted database without a local/self-hosted fallback.

## 8. Immediate migration backlog

The next architectural milestones should be implemented in this order:

1. Extract shared task, goal, library, reminder, and report domain rules from the Express routes.
2. Introduce a FastAPI backend with Pydantic schemas, SQLAlchemy repositories, and Alembic migrations.
3. Add a local Ollama provider and replace the Gemini dependency in the default AI path.
4. Define a portable SQLite/PostgreSQL repository interface and move production data off Vercel’s ephemeral filesystem.
5. Create the Flutter shell with Riverpod, Go Router, Material 3, secure storage, local notifications, and offline repositories.
6. Add local file directories, backups, SQLite FTS5 search, and optional ChromaDB semantic search.
7. Add Docker and self-hosted deployment documentation for the complete stack.

## 9. Project record convention

Each enhancement must update `PROJECT_STATUS.md` with the date, feature summary, tests, deployment status, and known limitations. Architectural decisions belong in `docs/`. Reusable scripts belong in `scripts/`. Database changes must be visible in migration files or a documented migration procedure. The repository history is the durable record of implementation progress.

> This workflow is now the default operating standard for future Productivity Boost Dashboard enhancements. If a future request conflicts with these rules, the conflict must be identified and resolved before implementation begins.
