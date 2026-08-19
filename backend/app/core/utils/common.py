from __future__ import annotations

import hashlib
import mimetypes
import re
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def new_id(prefix: str) -> str:
    return f"{prefix}-{uuid4().hex}"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("\x00", " ")).strip()


def tokenize(value: str) -> list[str]:
    return re.findall(r"[\w]{2,}", value.casefold(), flags=re.UNICODE)


def safe_filename(value: str, fallback: str = "asset") -> str:
    name = Path(value).name.strip()
    name = re.sub(r"[^\w.() -]+", "_", name, flags=re.UNICODE).strip(" .")
    return name or fallback


def extension_for(name: str) -> str:
    extension = Path(name).suffix.casefold()
    return extension if extension else ""


def mime_type_for(name: str) -> str:
    return mimetypes.guess_type(name)[0] or "application/octet-stream"
