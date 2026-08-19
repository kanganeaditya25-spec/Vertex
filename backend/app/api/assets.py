from __future__ import annotations

import hashlib
import mimetypes
import os
import re
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse, Response
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.assets.models import (
    AssetCollectionModel,
    AssetFolderModel,
    AssetModel,
    AssetSyncQueueModel,
    AssetVersionModel,
)
from app.assets.schemas import (
    AssetCollectionCreate,
    AssetCollectionRead,
    AssetCreate,
    AssetFolderCreate,
    AssetFolderRead,
    AssetLinkRequest,
    AssetRead,
    AssetStats,
    AssetUpdate,
    AssetUrlCreate,
    AssetVersionRead,
    BulkAssetAction,
    AssetExportRequest,
    OcrResult,
)
from app.db.session import get_db
from app.assets.services import build_zip, extract_ocr

router = APIRouter(prefix="/assets", tags=["assets"])
STORAGE_ROOT = Path(os.getenv("ASSET_STORAGE_ROOT", "./data/assets")).resolve()
STORAGE_ROOT.mkdir(parents=True, exist_ok=True)

_TEXT_EXTENSIONS = {".txt", ".md", ".markdown", ".json", ".csv", ".py", ".dart", ".js", ".ts", ".html", ".css", ".sql", ".yaml", ".yml", ".xml", ".log"}
_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg"}
_AUDIO_EXTENSIONS = {".mp3", ".wav", ".m4a", ".ogg", ".flac", ".aac"}
_VIDEO_EXTENSIONS = {".mp4", ".mov", ".avi", ".mkv", ".webm"}
_DOCUMENT_EXTENSIONS = {".pdf", ".doc", ".docx", ".ppt", ".pptx", ".xls", ".xlsx", ".zip"}


def _now() -> datetime:
    return datetime.now(UTC)


def _safe_filename(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._")
    return cleaned[:160] or "asset"


def _asset_type(name: str, mime_type: str) -> str:
    extension = Path(name).suffix.lower()
    if extension in _IMAGE_EXTENSIONS or mime_type.startswith("image/"):
        return "image"
    if extension in _AUDIO_EXTENSIONS or mime_type.startswith("audio/"):
        return "audio"
    if extension in _VIDEO_EXTENSIONS or mime_type.startswith("video/"):
        return "video"
    if extension == ".pdf" or mime_type == "application/pdf":
        return "pdf"
    if extension in _TEXT_EXTENSIONS or mime_type.startswith("text/"):
        return "text"
    if extension in _DOCUMENT_EXTENSIONS:
        return "document"
    return "file"


def _read(asset: AssetModel) -> AssetRead:
    values = {
        column.name: getattr(asset, column.name)
        for column in AssetModel.__table__.columns
        if column.name != "metadata_json"
    }
    values["metadata"] = asset.metadata_json or {}
    return AssetRead.model_validate(values)


def _queue(db: Session, asset: AssetModel, operation: str, payload: dict) -> None:
    db.add(
        AssetSyncQueueModel(
            id=f"{asset.id}:{operation}:{uuid4().hex[:8]}",
            asset_id=asset.id,
            operation=operation,
            payload=payload,
        )
    )


def _version(db: Session, asset: AssetModel, action: str) -> None:
    db.add(
        AssetVersionModel(
            id=str(uuid4()),
            asset_id=asset.id,
            version=asset.version or 1,
            action=action,
            name=asset.name,
            file_hash=asset.file_hash,
            size_bytes=asset.size_bytes,
            storage_key=asset.storage_key,
            metadata_json=asset.metadata_json or {},
        )
    )


def _get_or_404(db: Session, asset_id: str) -> AssetModel:
    asset = db.get(AssetModel, asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


def _apply_update(asset: AssetModel, payload: dict) -> None:
    for key, value in payload.items():
        if key == "metadata":
            setattr(asset, "metadata_json", value)
        elif hasattr(asset, key):
            setattr(asset, key, value)
    asset.version = (asset.version or 1) + 1
    asset.modified_at = _now()


@router.get("", response_model=list[AssetRead])
def list_assets(
    q: str = Query(default=""),
    folder_id: str | None = None,
    category: str | None = None,
    asset_type: str | None = None,
    workspace_id: str | None = None,
    project_id: str | None = None,
    tag: str | None = None,
    include_archived: bool = False,
    include_trashed: bool = False,
    favorite_only: bool = False,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
) -> list[AssetRead]:
    statement = select(AssetModel)
    if not include_archived:
        statement = statement.where(AssetModel.archived.is_(False))
    if not include_trashed:
        statement = statement.where(AssetModel.trashed.is_(False))
    if folder_id:
        statement = statement.where(AssetModel.folder_id == folder_id)
    if category:
        statement = statement.where(AssetModel.category == category)
    if asset_type:
        statement = statement.where(AssetModel.asset_type == asset_type)
    if workspace_id:
        statement = statement.where(AssetModel.workspace_id == workspace_id)
    if project_id:
        statement = statement.where(AssetModel.project_id == project_id)
    if favorite_only:
        statement = statement.where(AssetModel.favorite.is_(True))
    if tag:
        safe_tag = tag.replace('"', '')
        statement = statement.where(AssetModel.tags.like(f'%"{safe_tag}"%'))
    if q:
        like = f"%{q}%"
        statement = statement.where(
            or_(
                AssetModel.name.ilike(like),
                AssetModel.preview_text.ilike(like),
                AssetModel.ocr_text.ilike(like),
                AssetModel.category.ilike(like),
                AssetModel.file_hash.ilike(like),
            )
        )
    assets = db.scalars(statement.order_by(AssetModel.modified_at.desc()).limit(limit)).all()
    return [_read(asset) for asset in assets]


@router.post("", response_model=AssetRead, status_code=status.HTTP_201_CREATED)
def create_asset(payload: AssetCreate, db: Session = Depends(get_db)) -> AssetRead:
    asset_id = payload.id or f"asset-{uuid4().hex}"
    if db.get(AssetModel, asset_id) is not None:
        raise HTTPException(status_code=409, detail="Asset ID already exists")
    duplicate = db.scalar(select(AssetModel).where(AssetModel.file_hash == payload.file_hash, AssetModel.file_hash != ""))
    if duplicate is not None:
        raise HTTPException(status_code=409, detail=f"Duplicate asset detected: {duplicate.id}")
    asset = AssetModel(
        id=asset_id,
        **payload.model_dump(exclude={"id", "metadata"}),
        metadata_json=payload.metadata,
    )
    db.add(asset)
    _version(db, asset, "upload")
    _queue(db, asset, "create", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(asset)
    return _read(asset)


@router.post("/url", response_model=AssetRead, status_code=status.HTTP_201_CREATED)
def create_url_asset(payload: AssetUrlCreate, db: Session = Depends(get_db)) -> AssetRead:
    url = str(payload.url)
    digest = hashlib.sha256(url.encode()).hexdigest()
    duplicate = db.scalar(select(AssetModel).where(AssetModel.file_hash == digest))
    if duplicate is not None:
        return _read(duplicate)
    asset = AssetModel(
        id=f"asset-{uuid4().hex}",
        name=payload.name,
        asset_type="url",
        source_kind="url",
        extension="",
        mime_type="text/html",
        file_hash=digest,
        source_url=url,
        preview_text=payload.description,
        thumbnail_key=payload.thumbnail_url,
        category=payload.category,
        tags=payload.tags,
        metadata_json={"description": payload.description, "thumbnail_url": payload.thumbnail_url},
    )
    db.add(asset)
    _version(db, asset, "create_url")
    _queue(db, asset, "create", {"source_url": url, "name": payload.name})
    db.commit()
    db.refresh(asset)
    return _read(asset)


@router.post("/upload", response_model=AssetRead, status_code=status.HTTP_201_CREATED)
def upload_asset(
    file: UploadFile = File(...),
    workspace_id: str = "",
    project_id: str = "",
    folder_id: str = "root",
    category: str = "uncategorized",
    tags: str = "",
    db: Session = Depends(get_db),
) -> AssetRead:
    original_name = _safe_filename(file.filename or "asset")
    digest = hashlib.sha256()
    temporary = STORAGE_ROOT / f".upload-{uuid4().hex}.part"
    size = 0
    try:
        with temporary.open("wb") as output:
            while chunk := file.file.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
                size += len(chunk)
        file_hash = digest.hexdigest()
        duplicate = db.scalar(select(AssetModel).where(AssetModel.file_hash == file_hash))
        if duplicate is not None:
            temporary.unlink(missing_ok=True)
            return _read(duplicate)
        extension = Path(original_name).suffix.lower()
        mime_type = file.content_type or mimetypes.guess_type(original_name)[0] or "application/octet-stream"
        storage_key = f"{file_hash[:2]}/{file_hash}-{original_name}"
        destination = STORAGE_ROOT / storage_key
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary.replace(destination)
        preview_text = ""
        if extension in _TEXT_EXTENSIONS and size <= 2_000_000:
            preview_text = destination.read_text(encoding="utf-8", errors="replace")[:200_000]
        asset = AssetModel(
            id=f"asset-{uuid4().hex}",
            name=original_name,
            asset_type=_asset_type(original_name, mime_type),
            source_kind="file",
            extension=extension,
            mime_type=mime_type,
            size_bytes=size,
            file_hash=file_hash,
            storage_key=storage_key,
            preview_text=preview_text,
            workspace_id=workspace_id,
            project_id=project_id,
            folder_id=folder_id,
            category=category,
            tags=[value.strip() for value in tags.split(",") if value.strip()],
            metadata_json={"original_filename": file.filename or original_name},
        )
        db.add(asset)
        _version(db, asset, "upload")
        _queue(db, asset, "create", {"storage_key": storage_key, "file_hash": file_hash})
        db.commit()
        db.refresh(asset)
        return _read(asset)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    finally:
        file.file.close()


@router.get("/{asset_id}", response_model=AssetRead)
def get_asset(asset_id: str, db: Session = Depends(get_db)) -> AssetRead:
    return _read(_get_or_404(db, asset_id))


@router.patch("/{asset_id}", response_model=AssetRead)
def update_asset(asset_id: str, payload: AssetUpdate, db: Session = Depends(get_db)) -> AssetRead:
    asset = _get_or_404(db, asset_id)
    changes = payload.model_dump(exclude_unset=True)
    previous_name = asset.name
    _apply_update(asset, changes)
    _version(db, asset, "rename" if "name" in changes and changes["name"] != previous_name else "edit")
    _queue(db, asset, "update", changes)
    db.commit()
    db.refresh(asset)
    return _read(asset)


@router.delete("/{asset_id}", response_model=AssetRead)
def trash_asset(asset_id: str, db: Session = Depends(get_db)) -> AssetRead:
    asset = _get_or_404(db, asset_id)
    _apply_update(asset, {"trashed": True})
    _version(db, asset, "delete")
    _queue(db, asset, "delete", {"id": asset.id})
    db.commit()
    db.refresh(asset)
    return _read(asset)


@router.post("/{asset_id}/restore", response_model=AssetRead)
def restore_asset(asset_id: str, db: Session = Depends(get_db)) -> AssetRead:
    asset = _get_or_404(db, asset_id)
    _apply_update(asset, {"trashed": False, "archived": False})
    _version(db, asset, "restore")
    _queue(db, asset, "restore", {"id": asset.id})
    db.commit()
    db.refresh(asset)
    return _read(asset)


@router.get("/{asset_id}/content")
def get_asset_content(asset_id: str, db: Session = Depends(get_db)) -> FileResponse:
    asset = _get_or_404(db, asset_id)
    if not asset.storage_key:
        raise HTTPException(status_code=404, detail="Asset has no local file content")
    path = (STORAGE_ROOT / asset.storage_key).resolve()
    if STORAGE_ROOT not in path.parents or not path.is_file():
        raise HTTPException(status_code=404, detail="Stored asset content not found")
    return FileResponse(path, media_type=asset.mime_type, filename=asset.name)


@router.get("/{asset_id}/versions", response_model=list[AssetVersionRead])
def list_versions(asset_id: str, db: Session = Depends(get_db)) -> list[AssetVersionRead]:
    _get_or_404(db, asset_id)
    versions = db.scalars(select(AssetVersionModel).where(AssetVersionModel.asset_id == asset_id).order_by(AssetVersionModel.version.desc())).all()
    return [AssetVersionRead.model_validate(version) for version in versions]


@router.post("/{asset_id}/link", response_model=AssetRead)
def link_asset(asset_id: str, payload: AssetLinkRequest, db: Session = Depends(get_db)) -> AssetRead:
    asset = _get_or_404(db, asset_id)
    field = {
        "task": "linked_task_ids",
        "note": "linked_note_ids",
        "event": "linked_event_ids",
        "goal": "linked_goal_ids",
        "reminder": "linked_reminder_ids",
        "assistant": "linked_assistant_thread_ids",
    }[payload.relation]
    values = list(getattr(asset, field) or [])
    if payload.linked and payload.related_id not in values:
        values.append(payload.related_id)
    if not payload.linked:
        values = [value for value in values if value != payload.related_id]
    _apply_update(asset, {field: values})
    _queue(db, asset, "link", {"relation": payload.relation, "related_id": payload.related_id, "linked": payload.linked})
    db.commit()
    db.refresh(asset)
    return _read(asset)


@router.post("/bulk", response_model=list[AssetRead])
def bulk_action(payload: BulkAssetAction, db: Session = Depends(get_db)) -> list[AssetRead]:
    assets = db.scalars(select(AssetModel).where(AssetModel.id.in_(payload.asset_ids))).all()
    if len(assets) != len(set(payload.asset_ids)):
        raise HTTPException(status_code=404, detail="One or more assets were not found")
    for asset in assets:
        if payload.action == "move" and payload.folder_id:
            _apply_update(asset, {"folder_id": payload.folder_id})
        elif payload.action == "tag" and payload.tags is not None:
            _apply_update(asset, {"tags": payload.tags})
        elif payload.action == "delete":
            _apply_update(asset, {"trashed": True})
        elif payload.action == "restore":
            _apply_update(asset, {"trashed": False, "archived": False})
        elif payload.action == "archive":
            _apply_update(asset, {"archived": True})
        elif payload.action == "favorite":
            _apply_update(asset, {"favorite": True})
        elif payload.action == "pin":
            _apply_update(asset, {"pinned": True})
        elif payload.action == "export":
            continue
        _version(db, asset, payload.action)
        _queue(db, asset, f"bulk_{payload.action}", payload.model_dump(mode="json"))
    db.commit()
    return [_read(asset) for asset in assets]


@router.get("/folders/list", response_model=list[AssetFolderRead])
def list_folders(include_archived: bool = False, db: Session = Depends(get_db)) -> list[AssetFolderRead]:
    statement = select(AssetFolderModel)
    if not include_archived:
        statement = statement.where(AssetFolderModel.archived.is_(False))
    folders = db.scalars(statement.order_by(AssetFolderModel.name.asc())).all()
    return [AssetFolderRead.model_validate(folder) for folder in folders]


@router.post("/folders", response_model=AssetFolderRead, status_code=status.HTTP_201_CREATED)
def create_folder(payload: AssetFolderCreate, db: Session = Depends(get_db)) -> AssetFolderRead:
    existing = db.scalar(select(AssetFolderModel).where(AssetFolderModel.parent_id == payload.parent_id, AssetFolderModel.name == payload.name))
    if existing is not None:
        raise HTTPException(status_code=409, detail="Folder already exists")
    folder = AssetFolderModel(id=f"folder-{uuid4().hex}", **payload.model_dump())
    db.add(folder)
    db.commit()
    db.refresh(folder)
    return AssetFolderRead.model_validate(folder)


@router.get("/collections/list", response_model=list[AssetCollectionRead])
def list_collections(db: Session = Depends(get_db)) -> list[AssetCollectionRead]:
    return [AssetCollectionRead.model_validate(item) for item in db.scalars(select(AssetCollectionModel).order_by(AssetCollectionModel.name.asc())).all()]


@router.post("/collections", response_model=AssetCollectionRead, status_code=status.HTTP_201_CREATED)
def create_collection(payload: AssetCollectionCreate, db: Session = Depends(get_db)) -> AssetCollectionRead:
    collection = AssetCollectionModel(id=f"collection-{uuid4().hex}", **payload.model_dump())
    db.add(collection)
    db.commit()
    db.refresh(collection)
    return AssetCollectionRead.model_validate(collection)


@router.post("/ocr/{asset_id}", response_model=OcrResult)
def run_ocr(asset_id: str, db: Session = Depends(get_db)) -> OcrResult:
    asset = _get_or_404(db, asset_id)
    if not asset.storage_key:
        raise HTTPException(status_code=404, detail="Asset has no local file content")
    path = (STORAGE_ROOT / asset.storage_key).resolve()
    if STORAGE_ROOT not in path.parents or not path.is_file():
        raise HTTPException(status_code=404, detail="Stored asset content not found")
    try:
        text = extract_ocr(path)
    except FileNotFoundError as error:
        raise HTTPException(status_code=503, detail="Tesseract OCR is not installed") from error
    except TimeoutError as error:
        raise HTTPException(status_code=504, detail="OCR timed out") from error
    except RuntimeError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    _apply_update(asset, {"ocr_text": text})
    _version(db, asset, "ocr")
    _queue(db, asset, "ocr", {"characters": len(text)})
    db.commit()
    db.refresh(asset)
    return OcrResult(asset=_read(asset), text=text, engine="tesseract", pages_processed=1)


@router.post("/export", response_class=Response)
def export_assets(payload: AssetExportRequest, db: Session = Depends(get_db)) -> Response:
    assets = db.scalars(select(AssetModel).where(AssetModel.id.in_(payload.asset_ids))).all()
    if len(assets) != len(set(payload.asset_ids)):
        raise HTTPException(status_code=404, detail="One or more assets were not found")
    data = build_zip(assets, STORAGE_ROOT)
    filename = _safe_filename(payload.filename)
    return Response(content=data, media_type="application/zip", headers={"Content-Disposition": f'attachment; filename="{filename}"'})


@router.get("/stats/summary", response_model=AssetStats)
def asset_stats(db: Session = Depends(get_db)) -> AssetStats:
    assets = db.scalars(select(AssetModel)).all()
    active = [asset for asset in assets if not asset.trashed]
    categories: dict[str, int] = {}
    for asset in active:
        categories[asset.category] = categories.get(asset.category, 0) + 1
    by_hash: dict[str, list[str]] = {}
    for asset in active:
        if asset.file_hash:
            by_hash.setdefault(asset.file_hash, []).append(asset.id)
    return AssetStats(
        total_storage_bytes=sum(asset.size_bytes for asset in active),
        file_count=len(active),
        archived_count=sum(asset.archived for asset in assets),
        trashed_count=sum(asset.trashed for asset in assets),
        favorite_count=sum(asset.favorite for asset in active),
        largest_files=[_read(asset) for asset in sorted(active, key=lambda item: item.size_bytes, reverse=True)[:5]],
        category_counts=categories,
        recent_uploads=[_read(asset) for asset in sorted(active, key=lambda item: item.created_at, reverse=True)[:5]],
        duplicate_groups=[ids for ids in by_hash.values() if len(ids) > 1],
    )
