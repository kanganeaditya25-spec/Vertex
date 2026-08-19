from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CoreSettings:
    environment: str = os.getenv("ENVIRONMENT", "development")
    storage_root: Path = Path(os.getenv("ASSET_STORAGE_ROOT", "./data/assets"))
    document_preview_root: Path = Path(os.getenv("DOCUMENT_PREVIEW_ROOT", "./data/previews"))
    max_upload_bytes: int = int(os.getenv("MAX_UPLOAD_BYTES", str(100 * 1024 * 1024)))
    max_preview_chars: int = int(os.getenv("MAX_PREVIEW_CHARS", "200000"))
    semantic_chunk_chars: int = int(os.getenv("SEMANTIC_CHUNK_CHARS", "1200"))
    semantic_chunk_overlap: int = int(os.getenv("SEMANTIC_CHUNK_OVERLAP", "160"))
    ocr_timeout_seconds: int = int(os.getenv("OCR_TIMEOUT_SECONDS", "120"))
    notifications_enabled: bool = os.getenv("NOTIFICATIONS_ENABLED", "true").casefold() == "true"
    log_level: str = os.getenv("CORE_LOG_LEVEL", "INFO")
    max_log_value_chars: int = int(os.getenv("MAX_LOG_VALUE_CHARS", "500"))
    max_metric_samples: int = int(os.getenv("MAX_METRIC_SAMPLES", "1000"))
    max_notification_items: int = int(os.getenv("MAX_NOTIFICATION_ITEMS", "500"))
    ai_provider: str = os.getenv("AI_PROVIDER", "disabled")

    def ensure_directories(self) -> None:
        self.storage_root.mkdir(parents=True, exist_ok=True)
        self.document_preview_root.mkdir(parents=True, exist_ok=True)


core_settings = CoreSettings()
