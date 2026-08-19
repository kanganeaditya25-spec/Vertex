from __future__ import annotations

from pathlib import Path

from app.core.document_engine.contracts import DocumentMetadata
from app.core.utils.common import extension_for, mime_type_for, sha256_bytes


def extract_metadata(path: Path, **extra: object) -> DocumentMetadata:
    stat = path.stat()
    return DocumentMetadata(
        name=path.name,
        extension=extension_for(path.name),
        mime_type=mime_type_for(path.name),
        size_bytes=stat.st_size,
        file_hash=sha256_bytes(path.read_bytes()),
        extra={"created_timestamp": stat.st_ctime, "modified_timestamp": stat.st_mtime, **extra},
    )
