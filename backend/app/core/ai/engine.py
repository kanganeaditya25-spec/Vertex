from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from app.core.analytics.metrics import metrics
from app.core.ai.contracts import AiProvider, AiRequest, AiResponse, DisabledAiProvider
from app.core.configuration.settings import core_settings
from app.core.logging.service import logger


class RuleBasedAiProvider:
    name = 'rule-based'

    def complete(self, request: AiRequest) -> AiResponse:
        prompt = ' '.join(request.prompt.strip().split())
        if not prompt:
            return AiResponse(
                text='Please provide a request so the local assistant can help.',
                model=self.name,
                metadata={'offline': True, 'deterministic': True},
            )
        context_note = f' Context available: {len(request.context)} item(s).' if request.context else ''
        return AiResponse(
            text=(
                'Local rule-based fallback: I can help break this request into '
                f'clear next steps.{context_note} Request received: {prompt[:500]}'
            ),
            model=self.name,
            metadata={'offline': True, 'deterministic': True},
        )


@dataclass(frozen=True)
class AiCapabilities:
    active_provider: str
    providers: tuple[str, ...]
    network_required: bool


class AiEngine:
    def __init__(self) -> None:
        self._providers: dict[str, AiProvider] = {}
        self.register(DisabledAiProvider())
        self.register(RuleBasedAiProvider())

    def register(self, provider: AiProvider) -> None:
        self._providers[provider.name] = provider

    def capabilities(self) -> AiCapabilities:
        active = core_settings.ai_provider
        if active not in self._providers:
            active = 'disabled'
        return AiCapabilities(
            active_provider=active,
            providers=tuple(sorted(self._providers)),
            network_required=False,
        )

    def complete(self, request: AiRequest) -> AiResponse:
        active = self.capabilities().active_provider
        provider = self._providers[active]
        try:
            metrics.increment(f'ai.requests.{active}')
            response = provider.complete(request)
            metrics.increment(f'ai.responses.{active}')
            return response
        except Exception as exc:  # pragma: no cover - defensive provider boundary
            metrics.increment('ai.errors')
            logger.error('AI provider failed; using disabled fallback', provider=active, error=str(exc))
            return self._providers['disabled'].complete(request)


ai_engine = AiEngine()
