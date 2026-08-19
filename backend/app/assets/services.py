from __future__ import annotations

import json
import subprocess
from io import BytesIO
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from app.assets.models import AssetModel


def extract_ocr(path: Path) -> str:
    result = subprocess.run(
        ["tesseract", str(path), "stdout"],
        check=False,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Tesseract OCR failed")
    return result.stdout.strip()


def build_zip(assets: list[AssetModel], storage_root: Path) -> bytes:
    output = BytesIO()
    manifest = {"assets": []}
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for asset in assets:
            entry = {
                "id": asset.id,
                "name": asset.name,
                "asset_type": asset.asset_type,
                "file_hash": asset.file_hash,
                "size_bytes": asset.size_bytes,
                "tags": asset.tags or [],
                "metadata": asset.metadata_json or {},
            }
            manifest["assets"].append(entry)
            if asset.storage_key:
                path = (storage_root / asset.storage_key).resolve()
                if storage_root in path.parents and path.is_file():
                    archive.write(path, arcname=f"files/{asset.name}")
        archive.writestr("manifest.json", json.dumps(manifest, indent=2, default=str))
    return output.getvalue()
