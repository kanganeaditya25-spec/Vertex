from io import BytesIO
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.document_engine import DocumentSource, process_document
from app.core.event_bus.bus import DomainEvent, EventBus
from app.core.search.index import FullTextIndex, SearchDocument
from app.core.storage.service import LocalContentStore
from app.core.sync.queue import SyncOperation, SyncQueue
from app.main import app

client = TestClient(app)


def test_markdown_engine_extracts_chunks_citations_preview_and_index(tmp_path: Path) -> None:
    path = tmp_path / "knowledge.md"
    path.write_text("# Focus\n\nDeep work requires a protected block.\n\n## Review\n\nReview the outcome.", encoding="utf-8")
    search_index = FullTextIndex()
    processed = __import__("app.core.document_engine.engine", fromlist=["DocumentEngine"]).DocumentEngine(search_index).process(DocumentSource(name=path.name, path=path, asset_id="asset-core-test"))

    assert processed.page_count == 2
    assert processed.chunks
    assert processed.citations
    assert processed.preview_path is not None and processed.preview_path.is_file()
    assert search_index.search("protected block")[0].document_id == "asset-core-test"


def test_local_store_deduplicates_and_protects_paths(tmp_path: Path) -> None:
    store = LocalContentStore(tmp_path)
    first = store.put("notes.txt", b"same bytes")
    second = store.put("renamed.txt", b"same bytes")

    assert first.file_hash == second.file_hash
    assert second.duplicate is True
    assert store.read(first.key) == b"same bytes"


def test_event_bus_and_sync_queue_are_deterministic() -> None:
    bus = EventBus()
    received: list[str] = []
    bus.subscribe("asset.processed", lambda event: received.append(event.payload["asset_id"]))
    bus.publish(DomainEvent("asset.processed", {"asset_id": "asset-1"}))
    queue = SyncQueue()
    operation = queue.enqueue(SyncOperation("asset", "asset-1", "process", {"chunks": 2}))

    assert received == ["asset-1"]
    assert queue.pending() == [operation]
    assert queue.acknowledge(operation.id) is True
    assert queue.pending() == []


def test_asset_processing_endpoint_persists_document_engine_output() -> None:
    uploaded = client.post(
        "/api/v1/assets/upload",
        files={"file": (f"core-{uuid4().hex}.md", BytesIO(b"# Core\n\nShared indexing infrastructure."), "text/markdown")},
    )
    assert uploaded.status_code == 201
    asset_id = uploaded.json()["id"]
    processed = client.post(f"/api/v1/assets/{asset_id}/process")

    assert processed.status_code == 200
    assert processed.json()["chunk_count"] >= 1
    assert processed.json()["citation_count"] >= 1
    assert "Shared indexing infrastructure" in processed.json()["text"]
    assert processed.json()["asset"]["metadata"]["chunk_count"] >= 1


def test_core_capabilities_and_runtime_contracts() -> None:
    capabilities = client.get("/api/v1/core/capabilities")
    metrics = client.get("/api/v1/core/metrics")
    pending = client.get("/api/v1/core/sync/pending")

    assert capabilities.status_code == 200
    assert "document_engine" in capabilities.json()
    assert "semantic_chunker" in capabilities.json()["document_engine"]
    assert metrics.status_code == 200
    assert "counters" in metrics.json()
    assert pending.status_code == 200
