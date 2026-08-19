from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(frozen=True)
class AiRequest:
    prompt: str
    system: str = ""
    context: list[str] = field(default_factory=list)
    temperature: float = 0.2
    max_tokens: int = 1200


@dataclass(frozen=True)
class AiResponse:
    text: str
    model: str
    usage: dict[str, int] = field(default_factory=dict)
    metadata: dict[str, Any] = field(default_factory=dict)


class AiProvider(Protocol):
    name: str

    def complete(self, request: AiRequest) -> AiResponse:
        ...


class DisabledAiProvider:
    name = "disabled"

    def complete(self, request: AiRequest) -> AiResponse:
        return AiResponse(text="", model=self.name, metadata={"reason": "no local AI provider configured"})
