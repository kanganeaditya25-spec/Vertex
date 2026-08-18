from dataclasses import dataclass, field
from datetime import UTC, datetime, time, timedelta
import re

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.assistant.schemas import AssistantAction, AssistantSource
from app.calendar.models import EventModel
from app.models.task import TaskModel
from app.notes.models import NoteModel


@dataclass(frozen=True)
class AssistantResult:
    content: str
    reasoning: str
    sources: list[AssistantSource] = field(default_factory=list)
    actions: list[AssistantAction] = field(default_factory=list)
    mode: str = "local_rule"


class LocalAssistantEngine:
    """A privacy-preserving rule engine that stays useful when Ollama is unavailable."""

    def respond(self, db: Session, message: str, include_sources: bool = True) -> AssistantResult:
        text = message.strip()
        lowered = text.casefold()
        if any(term in lowered for term in ("overdue", "late", "past due")) and "task" in lowered:
            return self.overdue_tasks(db)
        if ("today" in lowered and any(term in lowered for term in ("meeting", "calendar", "schedule"))) or "today's meetings" in lowered:
            return self.today_meetings(db)
        if "plan my week" in lowered or "plan the week" in lowered or "weekly plan" in lowered:
            return self.week_plan(db)
        if lowered.startswith("find ") or lowered.startswith("search ") or "find " in lowered:
            query = self._extract_search(text)
            return self.search(db, query, include_sources=include_sources)
        if lowered.startswith("open ") or lowered.startswith("show "):
            target = self._module_target(lowered)
            if target:
                return AssistantResult(f"Opening {target['label']}.", f"The command explicitly requested navigation to {target['label']}.", actions=[AssistantAction(action_type="navigate", label=f"Open {target['label']}", payload={"route": target["route"]})])
        if lowered.startswith("create task"):
            title = text[len("create task"):].strip(" :") or "New task"
            return AssistantResult(f"I prepared a task called **{title}** for review.", "Creating content is shown as a preview in the local fallback so nothing is added without a clear confirmation.", actions=[AssistantAction(action_type="create_task", label="Review task", payload={"title": title}, status="preview")])
        if lowered.startswith("create note"):
            title = text[len("create note"):].strip(" :") or "New note"
            return AssistantResult(f"I prepared a note called **{title}** for review.", "Creating content is shown as a preview in the local fallback so the user retains control of local workspace mutations.", actions=[AssistantAction(action_type="create_note", label="Review note", payload={"title": title}, status="preview")])
        return self.general_context(db, text)

    def search(self, db: Session, query: str, include_sources: bool = True) -> AssistantResult:
        normalized = query.strip()
        if not normalized:
            return AssistantResult("Tell me what to find across your tasks, notes, or calendar.", "No search phrase was detected.")
        term = f"%{normalized}%"
        sources: list[AssistantSource] = []
        tasks = db.scalars(select(TaskModel).where(TaskModel.deleted_at.is_(None), or_(TaskModel.title.ilike(term), TaskModel.description.ilike(term))).order_by(TaskModel.updated_at.desc()).limit(10)).all()
        sources.extend(AssistantSource(source_type="task", source_id=task.id, title=task.title, excerpt=task.description[:180], route="/tasks") for task in tasks)
        notes = db.scalars(select(NoteModel).where(NoteModel.deleted.is_(False), or_(NoteModel.title.ilike(term), NoteModel.plain_text.ilike(term), NoteModel.markdown_content.ilike(term))).order_by(NoteModel.updated_at.desc()).limit(10)).all()
        sources.extend(AssistantSource(source_type="note", source_id=note.id, title=note.title, excerpt=(note.summary or note.plain_text)[:180], route="/notes") for note in notes)
        events = db.scalars(select(EventModel).where(EventModel.deleted_at.is_(None), or_(EventModel.title.ilike(term), EventModel.description.ilike(term))).order_by(EventModel.start_at).limit(10)).all()
        sources.extend(AssistantSource(source_type="calendar", source_id=event.id, title=event.title, excerpt=event.description[:180], route="/calendar") for event in events)
        if not sources:
            return AssistantResult(f"I could not find anything matching **{normalized}**.", "The local keyword index searched task, note, and calendar text and found no match.")
        content = f"I found {len(sources)} workspace result{'s' if len(sources) != 1 else ''} for **{normalized}**."
        return AssistantResult(content, "The offline search checked task titles/descriptions, note projections, and calendar titles/descriptions.", sources=sources if include_sources else [])

    def overdue_tasks(self, db: Session) -> AssistantResult:
        now = datetime.now(UTC)
        tasks = db.scalars(select(TaskModel).where(TaskModel.deleted_at.is_(None), TaskModel.deadline.is_not(None), TaskModel.deadline < now, TaskModel.status.not_in(("completed", "cancelled", "archived", "deleted"))).order_by(TaskModel.deadline).limit(20)).all()
        sources = [AssistantSource(source_type="task", source_id=task.id, title=task.title, excerpt=f"Due {task.deadline:%Y-%m-%d %H:%M}", route="/tasks") for task in tasks]
        if not tasks:
            return AssistantResult("You have no overdue tasks in the local workspace.", "I checked active tasks with deadlines earlier than the current local time.")
        lines = "\n".join(f"- **{task.title}** — {task.priority}, due {task.deadline:%b %d %H:%M}" for task in tasks[:8])
        return AssistantResult(f"You have **{len(tasks)} overdue task{'s' if len(tasks) != 1 else ''}**:\n{lines}", "Tasks were ordered by deadline so the most time-sensitive work appears first.", sources=sources, actions=[AssistantAction(action_type="navigate", label="Open Smart Tasks", payload={"route": "/tasks"})])

    def today_meetings(self, db: Session) -> AssistantResult:
        now = datetime.now(UTC)
        start = datetime.combine(now.date(), time.min, tzinfo=UTC)
        end = start + timedelta(days=1)
        events = db.scalars(select(EventModel).where(EventModel.deleted_at.is_(None), EventModel.start_at < end, EventModel.end_at > start).order_by(EventModel.start_at).limit(30)).all()
        sources = [AssistantSource(source_type="calendar", source_id=event.id, title=event.title, excerpt=f"{event.start_at:%H:%M}–{event.end_at:%H:%M}", route="/calendar") for event in events]
        if not events:
            return AssistantResult("There are no calendar events scheduled today.", "I checked the local calendar between midnight and the end of today.", actions=[AssistantAction(action_type="navigate", label="Open Calendar", payload={"route": "/calendar"})])
        lines = "\n".join(f"- **{event.title}** — {event.start_at:%H:%M}–{event.end_at:%H:%M}" for event in events[:10])
        return AssistantResult(f"Today's schedule has **{len(events)} event{'s' if len(events) != 1 else ''}**:\n{lines}", "Events were ordered chronologically to make the day easy to scan.", sources=sources, actions=[AssistantAction(action_type="navigate", label="Open Calendar", payload={"route": "/calendar"})])

    def week_plan(self, db: Session) -> AssistantResult:
        now = datetime.now(UTC)
        end = now + timedelta(days=7)
        tasks = db.scalars(select(TaskModel).where(TaskModel.deleted_at.is_(None), TaskModel.status.not_in(("completed", "cancelled", "archived", "deleted"))).order_by(TaskModel.priority, TaskModel.deadline).limit(8)).all()
        events = db.scalars(select(EventModel).where(EventModel.deleted_at.is_(None), EventModel.start_at < end, EventModel.end_at > now).order_by(EventModel.start_at).limit(20)).all()
        sources = [AssistantSource(source_type="task", source_id=task.id, title=task.title, excerpt=f"{task.priority} priority", route="/tasks") for task in tasks[:5]] + [AssistantSource(source_type="calendar", source_id=event.id, title=event.title, excerpt=f"{event.start_at:%a %H:%M}", route="/calendar") for event in events[:5]]
        task_lines = "\n".join(f"- **{task.title}** — {task.priority}, about {task.estimated_minutes or 25} minutes" for task in tasks[:5]) or "- No active tasks were found."
        return AssistantResult(f"Here is a practical seven-day starting plan:\n{task_lines}\n\nProtect a focus block before the busiest calendar windows and leave recovery space between demanding tasks.", "The plan combines active task priority and estimated effort with the next seven days of calendar occupancy. It is a recommendation, not an automatic schedule change.", sources=sources, actions=[AssistantAction(action_type="navigate", label="Open Calendar", payload={"route": "/calendar"}), AssistantAction(action_type="navigate", label="Open Smart Tasks", payload={"route": "/tasks"})])

    def general_context(self, db: Session, text: str) -> AssistantResult:
        task_count = db.scalar(select(TaskModel.id).where(TaskModel.deleted_at.is_(None), TaskModel.status.not_in(("completed", "cancelled", "archived", "deleted"))).limit(1))
        note_count = db.scalar(select(NoteModel.id).where(NoteModel.deleted.is_(False)).limit(1))
        event_count = db.scalar(select(EventModel.id).where(EventModel.deleted_at.is_(None)).limit(1))
        available = sum(value is not None for value in (task_count, note_count, event_count))
        return AssistantResult("I am ready to help with your tasks, calendar, notes, and workspace search. Try **show overdue tasks**, **summarize today's meetings**, **plan my week**, **find React**, or **open notes**.", f"The local assistant recognized the request but no specialized command matched. It confirmed {available} supported workspace domains are available for context.")

    @staticmethod
    def _extract_search(text: str) -> str:
        match = re.search(r"(?:find|search)(?:\s+for)?\s+(.+)", text, re.IGNORECASE)
        return match.group(1).strip() if match else text.strip()

    @staticmethod
    def _module_target(text: str) -> dict[str, str] | None:
        targets = {"dashboard": ("Dashboard", "/"), "tasks": ("Smart Tasks", "/tasks"), "calendar": ("Calendar", "/calendar"), "notes": ("Second Brain Notes", "/notes"), "assistant": ("AI Assistant", "/assistant")}
        for key, (label, route) in targets.items():
            if key in text:
                return {"label": label, "route": route}
        return None


assistant_engine = LocalAssistantEngine()
