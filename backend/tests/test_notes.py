from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_note_lifecycle_blocks_links_search_and_history() -> None:
    first = client.post(
        "/api/v1/notes",
        json={
            "title": "Knowledge systems",
            "note_type": "research",
            "tags": ["knowledge", "research"],
            "blocks": [
                {"block_type": "heading1", "content": "Second brain"},
                {"block_type": "paragraph", "content": "A connected note should remain useful offline."},
                {"block_type": "checklist", "content": "Review backlinks", "checked": False},
            ],
        },
    )
    assert first.status_code == 201
    first_note = first.json()
    assert first_note["word_count"] >= 8
    assert first_note["markdown_content"].startswith("# Second brain")
    assert first_note["blocks"][2]["block_type"] == "checklist"

    second = client.post(
        "/api/v1/notes",
        json={"title": "Calendar research", "tags": ["research"], "blocks": [{"content": "Time intelligence links to knowledge."}]},
    )
    assert second.status_code == 201
    second_note = second.json()

    link = client.post("/api/v1/notes/link", json={"source_note_id": first_note["id"], "target_note_id": second_note["id"], "link_type": "supports"})
    assert link.status_code == 201

    updated = client.put(
        f"/api/v1/notes/{first_note['id']}",
        json={"title": "Connected knowledge systems", "change_summary": "Clarified the research title"},
    )
    assert updated.status_code == 200
    assert updated.json()["version"] == 2
    assert second_note["id"] in updated.json()["outgoing_note_ids"]

    search = client.post("/api/v1/notes/search", json={"query": "backlinks", "tags": ["knowledge"]})
    assert search.status_code == 200
    assert search.json()[0]["id"] == first_note["id"]

    versions = client.get(f"/api/v1/notes/{first_note['id']}/versions")
    history = client.get(f"/api/v1/notes/{first_note['id']}/history")
    assert versions.status_code == 200 and len(versions.json()) >= 2
    assert history.status_code == 200 and {item["action"] for item in history.json()} >= {"created", "edited", "linked"}

    archived = client.post(f"/api/v1/notes/{first_note['id']}/archive")
    assert archived.status_code == 200
    rejected = client.put(f"/api/v1/notes/{first_note['id']}", json={"title": "Should fail"})
    assert rejected.status_code == 409

    client.delete(f"/api/v1/notes/{first_note['id']}")
    client.delete(f"/api/v1/notes/{second_note['id']}")


def test_note_validation_and_statistics() -> None:
    invalid = client.post("/api/v1/notes", json={"title": "", "blocks": []})
    assert invalid.status_code == 422
    statistics = client.get("/api/v1/notes/statistics")
    assert statistics.status_code == 200
    assert set(statistics.json()) == {"total_notes", "archived_notes", "favorite_notes", "linked_notes", "total_words", "top_tags"}
