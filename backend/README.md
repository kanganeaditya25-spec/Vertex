# Productivity Dashboard API Foundation

This directory contains the staged FastAPI backend for the offline-first architecture. It is intentionally introduced beside the existing Express prototype so domain migration can happen incrementally.

## Local setup

From the repository root, create a Python 3.13+ virtual environment and install the backend dependencies:

```bash
cd backend
python3.13 -m venv .venv
. .venv/bin/activate
pip install -e '.[test]'
uvicorn app.main:app --reload
```

The health contract is available at `http://127.0.0.1:8000/api/v1/health`.

## Boundaries

`app/api` contains HTTP contracts, `app/services` contains domain logic, `app/repositories` owns persistence access, `app/models` contains database models, `app/providers` will contain replaceable local AI adapters, and `app/db` owns engine/session/migration boundaries. The first foundation endpoint does not yet replace the legacy Express API.

## Testing

```bash
pytest
```
