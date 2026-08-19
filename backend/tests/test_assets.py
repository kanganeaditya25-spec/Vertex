from io import BytesIO
from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_asset_metadata_lifecycle_search_versions_and_links() -> None:
    asset_id = f"acceptance-{uuid4().hex}"
    created = client.post(
        "/api/v1/assets",
        json={
            "id": asset_id,
            "name": "Architecture Notes.md",
            "asset_type": "text",
            "extension": ".md",
            "mime_type": "text/markdown",
            "file_hash": uuid4().hex,
            "preview_text": "offline asset architecture",
            "tags": ["architecture", "module11"],
            "category": "knowledge",
        },
    )
    assert created.status_code == 201
    assert created.json()["id"] == asset_id

    search = client.get("/api/v1/assets", params={"q": "architecture", "tag": "module11"})
    assert search.status_code == 200
    assert any(item["id"] == asset_id for item in search.json())

    linked = client.post(f"/api/v1/assets/{asset_id}/link", json={"relation": "note", "related_id": "note-1"})
    assert linked.status_code == 200
    assert linked.json()["linked_note_ids"] == ["note-1"]

    renamed = client.patch(f"/api/v1/assets/{asset_id}", json={"name": "Architecture Notes v2.md", "favorite": True})
    assert renamed.status_code == 200
    assert renamed.json()["favorite"] is True

    versions = client.get(f"/api/v1/assets/{asset_id}/versions")
    assert versions.status_code == 200
    assert len(versions.json()) >= 2

    deleted = client.delete(f"/api/v1/assets/{asset_id}")
    assert deleted.status_code == 200
    assert deleted.json()["trashed"] is True
    restored = client.post(f"/api/v1/assets/{asset_id}/restore")
    assert restored.status_code == 200
    assert restored.json()["trashed"] is False


def test_asset_upload_is_stored_and_deduplicated() -> None:
    content = b"# offline knowledge\nAsset Library upload acceptance\n"
    first = client.post(
        "/api/v1/assets/upload",
        files={"file": ("knowledge.md", BytesIO(content), "text/markdown")},
        data={"tags": "knowledge,module11"},
    )
    assert first.status_code == 201
    assert first.json()["asset_type"] == "text"
    assert first.json()["size_bytes"] == len(content)

    second = client.post(
        "/api/v1/assets/upload",
        files={"file": ("renamed.md", BytesIO(content), "text/markdown")},
    )
    assert second.status_code == 201
    assert second.json()["id"] == first.json()["id"]


def test_asset_url_folder_collection_bulk_and_stats() -> None:
    url = f"https://example.com/module11/{uuid4().hex}"
    saved = client.post("/api/v1/assets/url", json={"name": "Module 11 reference", "url": url, "tags": ["reference"]})
    assert saved.status_code == 201
    asset_id = saved.json()["id"]

    duplicate = client.post("/api/v1/assets/url", json={"name": "Duplicate reference", "url": url})
    assert duplicate.status_code == 201
    assert duplicate.json()["id"] == asset_id

    folder = client.post("/api/v1/assets/folders", json={"name": f"Knowledge {uuid4().hex[:8]}"})
    assert folder.status_code == 201
    moved = client.post("/api/v1/assets/bulk", json={"asset_ids": [asset_id], "action": "move", "folder_id": folder.json()["id"]})
    assert moved.status_code == 200
    assert moved.json()[0]["folder_id"] == folder.json()["id"]

    collection = client.post("/api/v1/assets/collections", json={"name": "Module 11 collection", "asset_ids": [asset_id]})
    assert collection.status_code == 201
    assert collection.json()["asset_ids"] == [asset_id]

    stats = client.get("/api/v1/assets/stats/summary")
    assert stats.status_code == 200
    assert stats.json()["file_count"] >= 1


def test_asset_export_returns_zip_manifest() -> None:
    created = client.post(
        "/api/v1/assets",
        json={"name": "Manifest asset", "asset_type": "text", "file_hash": uuid4().hex, "metadata": {"source": "acceptance"}},
    )
    assert created.status_code == 201
    response = client.post("/api/v1/assets/export", json={"asset_ids": [created.json()["id"]], "filename": "module11.zip"})
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/zip"
    assert response.content.startswith(b"PK")


def test_ocr_without_file_content_returns_clear_contract_error() -> None:
    created = client.post("/api/v1/assets", json={"name": "OCR metadata", "asset_type": "image", "file_hash": uuid4().hex})
    assert created.status_code == 201
    response = client.post(f"/api/v1/assets/ocr/{created.json()['id']}")
    assert response.status_code == 404
    assert "file content" in response.json()["detail"]
