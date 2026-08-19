from __future__ import annotations

import re
from urllib.parse import urlparse

URL_PATTERN = re.compile(r"https?://[^\s<>\"']+", flags=re.IGNORECASE)


def extract_urls(text: str) -> list[str]:
    seen: set[str] = set()
    urls: list[str] = []
    for match in URL_PATTERN.findall(text):
        url = match.rstrip(".,;:!?)]}")
        parsed = urlparse(url)
        if parsed.scheme in {"http", "https"} and parsed.netloc and url not in seen:
            urls.append(url)
            seen.add(url)
    return urls
