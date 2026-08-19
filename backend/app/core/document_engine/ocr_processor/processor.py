from __future__ import annotations

import subprocess
from pathlib import Path

from app.core.configuration.settings import core_settings
from app.core.utils.common import normalize_text


IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".bmp"}


def extract_ocr(path: Path) -> str:
    result = subprocess.run(
        ["tesseract", str(path), "stdout"],
        check=False,
        capture_output=True,
        text=True,
        timeout=core_settings.ocr_timeout_seconds,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "OCR processing failed")
    return normalize_text(result.stdout)[: core_settings.max_preview_chars]


def supports(path: Path) -> bool:
    return path.suffix.casefold() in IMAGE_EXTENSIONS
