import pytest

from app.providers.ollama import LocalAIUnavailable, OllamaProvider


def test_ollama_provider_degrades_when_runtime_is_missing() -> None:
    provider = OllamaProvider(base_url="http://127.0.0.1:1", timeout_seconds=0.1)
    assert provider.is_available() is False
    with pytest.raises(LocalAIUnavailable):
        provider.generate("Give me one short productivity tip.")
