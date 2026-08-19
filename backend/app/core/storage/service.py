from __future__ import annotations

import hashlib
import os
import tempfile
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

from app.core.security.service import resolve_child
from app.core.utils.common import extension_for, mime_type_for, safe_filename, sha256_bytes


@dataclass(frozen=True)
class StoredContent:
    key: str
    file_hash: str
    size_bytes: int
    mime_type: str
    extension: str
    duplicate: bool


class LocalContentStore:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def put_stream(self, filename: str, chunks: Iterable[bytes]) -> StoredContent:
        safe_name = safe_filename(filename)
        extension = extension_for(safe_name)
        descriptor, temporary_name = tempfile.mkstemp(prefix=".upload-", dir=self.root)
        digest = hashlib.sha256()
        size = 0
        try:
            with os.fdopen(descriptor, "wb") as handle:
                for chunk in chunks:
                    if not chunk:
                        continue
                    digest.update(chunk)
                    handle.write(chunk)
                    size += len(chunk)
                handle.flush()
                os.fsync(handle.fileno())
            file_hash = digest.hexdigest()
            folder = self.root / file_hash[:2]
            folder.mkdir(parents=True, exist_ok=True)
            existing = next(folder.glob(f"{file_hash}-*"), None)
            if existing is not None and existing.is_file():
                return StoredContent(existing.relative_to(self.root).as_posix(), file_hash, size, mime_type_for(safe_name), extension, True)
            key = f"{file_hash[:2]}/{file_hash}-{safe_name}"
            target = resolve_child(self.root, key)
            os.replace(temporary_name, target)
            return StoredContent(key, file_hash, size, mime_type_for(safe_name), extension, False)
        finally:
            if os.path.exists(temporary_name):
                os.unlink(temporary_name)

    def put(self, filename: str, content: bytes) -> StoredContent:
        file_hash = sha256_bytes(content)
        safe_name = safe_filename(filename)
        extension = extension_for(safe_name)
        folder = self.root / file_hash[:2]
        folder.mkdir(parents=True, exist_ok=True)
        existing = next(folder.glob(f"{file_hash}-*"), None)
        if existing is not None and existing.is_file():
            existing_key = existing.relative_to(self.root).as_posix()
            return StoredContent(existing_key, file_hash, len(content), mime_type_for(safe_name), extension, True)
        key = f"{file_hash[:2]}/{file_hash}-{safe_name}"
        target = resolve_child(self.root, key)
        descriptor, temporary_name = tempfile.mkstemp(prefix=".upload-", dir=folder)
        try:
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(content)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_name, target)
        finally:
            if os.path.exists(temporary_name):
                os.unlink(temporary_name)
        return StoredContent(key, file_hash, len(content), mime_type_for(safe_name), extension, False)

    def path_for(self, key: str) -> Path:
        path = resolve_child(self.root, key)
        if not path.is_file():
            raise FileNotFoundError(key)
        return path

    def read(self, key: str) -> bytes:
        return self.path_for(key).read_bytes()

    def delete(self, key: str) -> None:
        path = self.path_for(key)
        path.unlink()
