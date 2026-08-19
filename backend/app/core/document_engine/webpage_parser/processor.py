from __future__ import annotations

from dataclasses import dataclass, field

import requests
from bs4 import BeautifulSoup

from app.core.utils.common import normalize_text


@dataclass(frozen=True)
class ParsedWebpage:
    url: str
    title: str
    description: str
    text: str
    canonical_url: str = ""
    image_url: str = ""
    metadata: dict[str, str] = field(default_factory=dict)


def parse_webpage(url: str, timeout: float = 10.0, max_chars: int = 200_000) -> ParsedWebpage:
    response = requests.get(url, timeout=timeout, headers={"User-Agent": "FocusFlowDocumentEngine/1.0"})
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    for element in soup(["script", "style", "noscript", "svg"]):
        element.decompose()
    title = normalize_text(soup.title.get_text(" ", strip=True) if soup.title else "")
    description = _meta(soup, "description") or _meta(soup, "og:description")
    canonical = soup.find("link", rel="canonical")
    image_url = _meta(soup, "og:image")
    text = normalize_text(soup.get_text(" ", strip=True))[:max_chars]
    return ParsedWebpage(url=url, title=title, description=description, text=text, canonical_url=canonical.get("href", "") if canonical else "", image_url=image_url, metadata={"content_type": response.headers.get("content-type", "")})


def _meta(soup: BeautifulSoup, property_name: str) -> str:
    tag = soup.find("meta", attrs={"property": property_name}) or soup.find("meta", attrs={"name": property_name})
    return normalize_text(tag.get("content", "")) if tag else ""
