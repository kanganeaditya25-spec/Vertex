from __future__ import annotations

import hashlib
import hmac
import os
from pathlib import Path

def resolve_child(root: Path, relative_name: str) -> Path:
    relative = Path(relative_name)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Path escapes the configured storage root")
    candidate = (root / relative).resolve()
    root_resolved = root.resolve()
    if candidate != root_resolved and root_resolved not in candidate.parents:
        raise ValueError("Path escapes the configured storage root")
    return candidate


def hash_secret(secret: str, salt: bytes | None = None) -> tuple[str, str]:
    salt_bytes = salt or os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", secret.encode(), salt_bytes, 240_000)
    return salt_bytes.hex(), digest.hex()


def verify_secret(secret: str, salt_hex: str, digest_hex: str) -> bool:
    salt = bytes.fromhex(salt_hex)
    candidate = hashlib.pbkdf2_hmac("sha256", secret.encode(), salt, 240_000).hex()
    return hmac.compare_digest(candidate, digest_hex)


def redact(value: str, visible: int = 4) -> str:
    if len(value) <= visible:
        return "*" * len(value)
    return f"{value[:visible]}…"
