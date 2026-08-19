from __future__ import annotations

from pathlib import Path

from PIL import Image, UnidentifiedImageError

from app.core.utils.common import safe_filename


def generate_thumbnail(path: Path, output_root: Path, size: tuple[int, int] = (480, 320)) -> Path | None:
    output_root.mkdir(parents=True, exist_ok=True)
    try:
        with Image.open(path) as image:
            image.thumbnail(size)
            target = output_root / f"{safe_filename(path.stem)}-thumb.webp"
            image.convert("RGB").save(target, "WEBP", quality=82, method=6)
            return target
    except (UnidentifiedImageError, OSError):
        return None
