from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_assistant_chat_search_memory_and_brief() -> None:
    marker = f"assistant knowledge {uuid4()}"
    note = client.post("/api/v1/notes", json={"title": marker, "blocks": [{"content": "Offline executive assistant context."}], "tags": ["assistant"]})
    assert note.status_code == 201

    chat = client.post("/api/v1/assistant/chat", json={"message": f"find {marker}"})
    assert chat.status_code == 200
    response = chat.json()
    assert response["mode"] == "local_rule"
    assert response["conversation_id"]
    assert any(source["source_type"] == "note" for source in response["sources"])
    assert "offline" in response["reasoning"].lower()

    conversation = client.get(f"/api/v1/assistant/conversations/{response['conversation_id']}")
    assert conversation.status_code == 200
    assert len(conversation.json()["messages"]) == 2

    memory = client.post("/api/v1/assistant/memories", json={"content": "Prefer a quiet focus block before noon.", "memory_type": "preference", "importance": 85, "pinned": True})
    assert memory.status_code == 201
    memory_id = memory.json()["id"]
    memories = client.get("/api/v1/assistant/memories", params={"pinned_only": True})
    assert memories.status_code == 200
    assert any(item["id"] == memory_id for item in memories.json())

    search = client.post("/api/v1/assistant/search", json={"query": marker})
    assert search.status_code == 200
    assert any(item["source_type"] == "note" for item in search.json()["results"])

    navigation = client.post("/api/v1/assistant/chat", json={"message": "open notes"})
    assert navigation.status_code == 200
    assert navigation.json()["actions"][0]["action_type"] == "navigate"

    brief = client.get("/api/v1/assistant/brief/morning")
    assert brief.status_code == 200
    assert brief.json()["brief_type"] == "morning"


def test_assistant_fallback_is_useful_without_specialized_command() -> None:
    response = client.post("/api/v1/assistant/chat", json={"message": "Help me stay organized"})
    assert response.status_code == 200
    assert response.json()["mode"] == "local_rule"
    assert "tasks" in response.json()["content"].lower()
