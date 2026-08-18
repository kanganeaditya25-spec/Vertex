import json
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.notes.intelligence import note_intelligence
from app.notes.models import (
    FolderModel,
    NoteBlockModel,
    NoteHistoryModel,
    NoteLinkModel,
    NoteModel,
    NoteSyncQueueModel,
    NoteTagModel,
    NoteVersionModel,
)
from app.notes.schemas import (
    BlockInput,
    NoteCreate,
    NoteHistoryRead,
    NoteLinkCreate,
    NoteRead,
    NoteSearchRequest,
    NoteStatistics,
    NoteUpdate,
    NoteVersionRead,
)

router = APIRouter(prefix="/notes", tags=["notes"])


def _note_query():
    return select(NoteModel).options(selectinload(NoteModel.blocks), selectinload(NoteModel.tags), selectinload(NoteModel.outgoing_links), selectinload(NoteModel.incoming_links))


def _get_note(db: Session, note_id: str, include_deleted: bool = False) -> NoteModel:
    statement = _note_query().where(NoteModel.id == note_id)
    if not include_deleted:
        statement = statement.where(NoteModel.deleted.is_(False))
    note = db.scalar(statement)
    if note is None:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


def _blocks_payload(note: NoteModel) -> list[dict]:
    return [
        {
            "id": block.id,
            "note_id": block.note_id,
            "block_type": block.block_type,
            "content": block.content,
            "position": block.position,
            "checked": block.checked,
            "collapsed": block.collapsed,
            "metadata": json.loads(block.metadata_json or "{}"),
            "created_at": block.created_at,
            "updated_at": block.updated_at,
        }
        for block in note.blocks
    ]


def _serialize(note: NoteModel) -> dict:
    return {
        "id": note.id,
        "title": note.title,
        "note_type": note.note_type,
        "summary": note.summary,
        "markdown_content": note.markdown_content,
        "folder_id": note.folder_id,
        "workspace": note.workspace,
        "project_id": note.project_id,
        "color": note.color,
        "icon": note.icon,
        "pinned": note.pinned,
        "favorite": note.favorite,
        "archived": note.archived,
        "deleted": note.deleted,
        "word_count": note.word_count,
        "reading_time_minutes": note.reading_time_minutes,
        "language": note.language,
        "knowledge_score": note.knowledge_score,
        "importance_score": note.importance_score,
        "version": note.version,
        "sync_status": note.sync_status,
        "created_at": note.created_at,
        "updated_at": note.updated_at,
        "archived_at": note.archived_at,
        "deleted_at": note.deleted_at,
        "tags": [{"name": tag.name, "color": tag.color} for tag in note.tags],
        "blocks": _blocks_payload(note),
        "outgoing_note_ids": [link.target_note_id for link in note.outgoing_links],
        "incoming_note_ids": [link.source_note_id for link in note.incoming_links],
    }


def _record(db: Session, note: NoteModel, action: str, details: str = "") -> None:
    db.add(NoteHistoryModel(id=str(uuid4()), note_id=note.id, action=action, details=details))


def _queue(db: Session, note: NoteModel, operation: str) -> None:
    db.add(NoteSyncQueueModel(id=str(uuid4()), note_id=note.id, operation=operation, version=note.version, payload=json.dumps({"id": note.id, "version": note.version, "operation": operation})))


def _validate_folder(db: Session, folder_id: str | None) -> None:
    if folder_id and db.scalar(select(FolderModel.id).where(FolderModel.id == folder_id)) is None:
        raise HTTPException(status_code=422, detail="Folder does not exist")


def _set_tags(db: Session, note: NoteModel, names: list[str]) -> None:
    note.tags.clear()
    for name in dict.fromkeys(value.strip().lower() for value in names if value.strip()):
        note.tags.append(NoteTagModel(id=str(uuid4()), note_id=note.id, name=name))


def _set_blocks(note: NoteModel, blocks: list[BlockInput | dict]) -> None:
    note.blocks.clear()
    for position, item in enumerate(blocks):
        data = item.model_dump() if isinstance(item, BlockInput) else item
        note.blocks.append(NoteBlockModel(id=str(uuid4()), note_id=note.id, block_type=data.get("block_type", "paragraph"), content=data.get("content", ""), position=position, checked=data.get("checked", False), collapsed=data.get("collapsed", False), metadata_json=json.dumps(data.get("metadata", {}))))


def _create_version(db: Session, note: NoteModel, summary: str) -> None:
    db.add(NoteVersionModel(id=str(uuid4()), note_id=note.id, version=note.version, title=note.title, blocks_json=json.dumps(_blocks_payload(note), default=str), change_summary=summary))


def _apply_projection(note: NoteModel) -> None:
    metadata = note_intelligence.project(note.title, _blocks_payload(note))
    note.plain_text = metadata.plain_text
    note.markdown_content = metadata.markdown
    note.word_count = metadata.word_count
    note.reading_time_minutes = metadata.reading_time_minutes
    note.knowledge_score = metadata.knowledge_score


@router.post("", response_model=NoteRead, status_code=status.HTTP_201_CREATED)
def create_note(payload: NoteCreate, db: Session = Depends(get_db)) -> dict:
    _validate_folder(db, payload.folder_id)
    note = NoteModel(id=str(uuid4()), title=payload.title.strip(), note_type=payload.note_type, summary=payload.summary, folder_id=payload.folder_id, workspace=payload.workspace, project_id=payload.project_id, color=payload.color, icon=payload.icon, pinned=payload.pinned, favorite=payload.favorite, importance_score=payload.importance_score)
    db.add(note)
    db.flush()
    _set_blocks(note, payload.blocks)
    _set_tags(db, note, payload.tags)
    _apply_projection(note)
    _create_version(db, note, "Created note")
    _record(db, note, "created")
    _queue(db, note, "create")
    db.commit()
    return _serialize(_get_note(db, note.id))


@router.get("", response_model=list[NoteRead])
def list_notes(search: str | None = None, favorite: bool | None = None, pinned: bool | None = None, note_type: str | None = None, include_archived: bool = False, limit: int = Query(default=100, ge=1, le=1000), db: Session = Depends(get_db)) -> list[dict]:
    statement = _note_query().where(NoteModel.deleted.is_(False))
    if not include_archived:
        statement = statement.where(NoteModel.archived.is_(False))
    if search:
        term = f"%{search.strip()}%"
        statement = statement.where(or_(NoteModel.title.ilike(term), NoteModel.plain_text.ilike(term), NoteModel.markdown_content.ilike(term)))
    if favorite is not None:
        statement = statement.where(NoteModel.favorite == favorite)
    if pinned is not None:
        statement = statement.where(NoteModel.pinned == pinned)
    if note_type:
        statement = statement.where(NoteModel.note_type == note_type)
    statement = statement.order_by(NoteModel.pinned.desc(), NoteModel.updated_at.desc()).limit(limit)
    return [_serialize(note) for note in db.scalars(statement).unique().all()]


@router.get("/recent", response_model=list[NoteRead])
def recent_notes(limit: int = Query(default=20, ge=1, le=100), db: Session = Depends(get_db)) -> list[dict]:
    statement = _note_query().where(NoteModel.deleted.is_(False), NoteModel.archived.is_(False)).order_by(NoteModel.updated_at.desc()).limit(limit)
    return [_serialize(note) for note in db.scalars(statement).unique().all()]


@router.get("/favorites", response_model=list[NoteRead])
def favorite_notes(db: Session = Depends(get_db)) -> list[dict]:
    statement = _note_query().where(NoteModel.deleted.is_(False), NoteModel.favorite.is_(True)).order_by(NoteModel.pinned.desc(), NoteModel.updated_at.desc())
    return [_serialize(note) for note in db.scalars(statement).unique().all()]


@router.post("/search", response_model=list[NoteRead])
def search_notes(payload: NoteSearchRequest, db: Session = Depends(get_db)) -> list[dict]:
    statement = _note_query().where(NoteModel.deleted.is_(False))
    if not payload.include_archived:
        statement = statement.where(NoteModel.archived.is_(False))
    term = f"%{payload.query.strip()}%"
    statement = statement.where(or_(NoteModel.title.ilike(term), NoteModel.plain_text.ilike(term), NoteModel.markdown_content.ilike(term), NoteModel.summary.ilike(term)))
    if payload.favorite_only:
        statement = statement.where(NoteModel.favorite.is_(True))
    statement = statement.order_by(NoteModel.pinned.desc(), NoteModel.updated_at.desc()).limit(payload.limit)
    notes = db.scalars(statement).unique().all()
    if payload.tags:
        expected = {tag.casefold() for tag in payload.tags}
        notes = [note for note in notes if expected.intersection({tag.name.casefold() for tag in note.tags})]
    return [_serialize(note) for note in notes]


@router.get("/statistics", response_model=NoteStatistics)
def note_statistics(db: Session = Depends(get_db)) -> NoteStatistics:
    notes = list(db.scalars(select(NoteModel).where(NoteModel.deleted.is_(False))).all())
    tags: dict[str, int] = {}
    for note in notes:
        for tag in note.tags:
            tags[tag.name] = tags.get(tag.name, 0) + 1
    return NoteStatistics(total_notes=len(notes), archived_notes=sum(note.archived for note in notes), favorite_notes=sum(note.favorite for note in notes), linked_notes=sum(bool(note.outgoing_links or note.incoming_links) for note in notes), total_words=sum(note.word_count for note in notes), top_tags=[{"name": name, "count": count} for name, count in sorted(tags.items(), key=lambda pair: -pair[1])[:10]])


@router.get("/{note_id}", response_model=NoteRead)
def get_note(note_id: str, db: Session = Depends(get_db)) -> dict:
    return _serialize(_get_note(db, note_id))


@router.put("/{note_id}", response_model=NoteRead)
def update_note(note_id: str, payload: NoteUpdate, db: Session = Depends(get_db)) -> dict:
    note = _get_note(db, note_id)
    if note.archived:
        raise HTTPException(status_code=409, detail="Archived notes are read-only")
    changes = payload.model_dump(exclude_unset=True)
    _validate_folder(db, changes.get("folder_id", note.folder_id))
    blocks = changes.pop("blocks", None)
    tags = changes.pop("tags", None)
    change_summary = changes.pop("change_summary", "Edited note")
    for key, value in changes.items():
        setattr(note, key, value)
    if blocks is not None:
        _set_blocks(note, blocks)
    if tags is not None:
        _set_tags(db, note, tags)
    note.version += 1
    note.sync_status = "pending"
    _apply_projection(note)
    _create_version(db, note, change_summary)
    _record(db, note, "edited", change_summary)
    _queue(db, note, "update")
    db.commit()
    return _serialize(_get_note(db, note.id))


@router.delete("/{note_id}", response_model=NoteRead)
def delete_note(note_id: str, db: Session = Depends(get_db)) -> dict:
    note = _get_note(db, note_id)
    note.deleted = True
    note.deleted_at = __import__("datetime").datetime.now(__import__("datetime").UTC)
    note.version += 1
    _record(db, note, "deleted")
    _queue(db, note, "delete")
    db.commit()
    return _serialize(note)


@router.post("/{note_id}/archive", response_model=NoteRead)
def archive_note(note_id: str, db: Session = Depends(get_db)) -> dict:
    note = _get_note(db, note_id)
    note.archived = True
    note.archived_at = __import__("datetime").datetime.now(__import__("datetime").UTC)
    note.version += 1
    _record(db, note, "archived")
    _queue(db, note, "archive")
    db.commit()
    return _serialize(note)


@router.post("/{note_id}/restore", response_model=NoteRead)
def restore_note(note_id: str, db: Session = Depends(get_db)) -> dict:
    note = _get_note(db, note_id, include_deleted=True)
    note.deleted = False
    note.deleted_at = None
    note.archived = False
    note.archived_at = None
    note.version += 1
    _record(db, note, "restored")
    _queue(db, note, "restore")
    db.commit()
    return _serialize(_get_note(db, note.id))


@router.post("/link", response_model=dict[str, str], status_code=status.HTTP_201_CREATED)
def create_link(payload: NoteLinkCreate, db: Session = Depends(get_db)) -> dict[str, str]:
    if payload.source_note_id == payload.target_note_id:
        raise HTTPException(status_code=422, detail="A note cannot link to itself")
    _get_note(db, payload.source_note_id)
    _get_note(db, payload.target_note_id)
    existing = db.scalar(select(NoteLinkModel).where(NoteLinkModel.source_note_id == payload.source_note_id, NoteLinkModel.target_note_id == payload.target_note_id, NoteLinkModel.link_type == payload.link_type))
    if existing:
        return {"id": existing.id, "status": "existing"}
    link = NoteLinkModel(id=str(uuid4()), source_note_id=payload.source_note_id, target_note_id=payload.target_note_id, link_type=payload.link_type)
    db.add(link)
    source = _get_note(db, payload.source_note_id)
    target = _get_note(db, payload.target_note_id)
    _record(db, source, "linked", f"to:{target.id}")
    _record(db, target, "linked", f"from:{source.id}")
    db.commit()
    return {"id": link.id, "status": "created"}


@router.delete("/link", response_model=dict[str, str])
def delete_link(payload: NoteLinkCreate, db: Session = Depends(get_db)) -> dict[str, str]:
    link = db.scalar(select(NoteLinkModel).where(NoteLinkModel.source_note_id == payload.source_note_id, NoteLinkModel.target_note_id == payload.target_note_id, NoteLinkModel.link_type == payload.link_type))
    if link is None:
        raise HTTPException(status_code=404, detail="Note link not found")
    db.delete(link)
    db.commit()
    return {"status": "deleted"}


@router.get("/{note_id}/versions", response_model=list[NoteVersionRead])
def note_versions(note_id: str, db: Session = Depends(get_db)) -> list[NoteVersionModel]:
    _get_note(db, note_id, include_deleted=True)
    return list(db.scalars(select(NoteVersionModel).where(NoteVersionModel.note_id == note_id).order_by(NoteVersionModel.version.desc())).all())


@router.get("/{note_id}/history", response_model=list[NoteHistoryRead])
def note_history(note_id: str, db: Session = Depends(get_db)) -> list[NoteHistoryModel]:
    _get_note(db, note_id, include_deleted=True)
    return list(db.scalars(select(NoteHistoryModel).where(NoteHistoryModel.note_id == note_id).order_by(NoteHistoryModel.created_at.desc())).all())


@router.post("/folders", response_model=dict[str, str], status_code=status.HTTP_201_CREATED)
def create_folder(name: str = Query(min_length=1, max_length=120), parent_id: str | None = None, db: Session = Depends(get_db)) -> dict[str, str]:
    if parent_id and db.scalar(select(FolderModel.id).where(FolderModel.id == parent_id)) is None:
        raise HTTPException(status_code=422, detail="Parent folder does not exist")
    folder = FolderModel(id=str(uuid4()), name=name.strip(), parent_id=parent_id)
    db.add(folder)
    db.commit()
    return {"id": folder.id, "name": folder.name}
