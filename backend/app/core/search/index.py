from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from app.core.utils.common import normalize_text, tokenize


@dataclass
class SearchDocument:
    document_id: str
    title: str
    text: str
    source_type: str = "asset"
    source_url: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def normalized_text(self) -> str:
        return normalize_text(f"{self.title} {self.text}")


@dataclass(frozen=True)
class SearchHit:
    document_id: str
    title: str
    score: float
    snippet: str
    source_type: str
    source_url: str
    metadata: dict[str, Any]


class FullTextIndex:
    def __init__(self) -> None:
        self._documents: dict[str, SearchDocument] = {}
        self._tokens: dict[str, set[str]] = {}

    def upsert(self, document: SearchDocument) -> None:
        self._documents[document.document_id] = document
        self._tokens[document.document_id] = set(tokenize(document.normalized_text))

    def remove(self, document_id: str) -> None:
        self._documents.pop(document_id, None)
        self._tokens.pop(document_id, None)

    def search(self, query: str, limit: int = 20) -> list[SearchHit]:
        normalized_query = normalize_text(query)
        query_tokens = tokenize(normalized_query)
        if not query_tokens:
            return []
        hits: list[SearchHit] = []
        for document_id, document in self._documents.items():
            token_set = self._tokens.get(document_id, set())
            matched = sum(token in token_set for token in query_tokens)
            if not matched:
                continue
            score = matched / len(query_tokens)
            if normalized_query.casefold() in document.normalized_text.casefold():
                score += 1.0
            snippet = self._snippet(document.normalized_text, query_tokens)
            hits.append(SearchHit(document_id, document.title, score, snippet, document.source_type, document.source_url, document.metadata))
        hits.sort(key=lambda hit: (-hit.score, hit.title.casefold()))
        return hits[:limit]

    @staticmethod
    def _snippet(text: str, query_tokens: list[str], width: int = 220) -> str:
        lowered = text.casefold()
        positions = [lowered.find(token.casefold()) for token in query_tokens if lowered.find(token.casefold()) >= 0]
        start = max(0, min(positions, default=0) - width // 3)
        return text[start : start + width].strip()


index = FullTextIndex()
