from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.calendar.models import EventModel
from app.db.session import get_db
from app.notes.models import NoteModel
from app.models.task import TaskModel
from app.organization.engine import dependency_conflicts, deadline_risk, effective_project_progress, project_manager_plan, project_recommendations, project_summary, search_score
from app.organization.models import Goal, Milestone, OrganizationSyncQueue, Project, ProjectTemplate, Workspace
from app.organization.schemas import (
    DependencyCheck,
    DependencyConflict,
    GoalCreate,
    GoalRead,
    GoalUpdate,
    MilestoneCreate,
    MilestoneRead,
    MilestoneUpdate,
    OrganizationSearchResponse,
    OrganizationSearchResult,
    OrganizationStats,
    ProjectCreate,
    ProjectChatRequest,
    ProjectChatResponse,
    ProjectDashboard,
    ProjectExport,
    ProjectManagerPlan,
    ProjectIntelligence,
    ProjectRead,
    ProjectTemplateCreate,
    ProjectTemplateRead,
    ProjectUpdate,
    WorkspaceCreate,
    WorkspaceRead,
    WorkspaceSummary,
    WorkspaceUpdate,
)

router = APIRouter(prefix="/organization", tags=["organization"])

DEFAULT_TEMPLATES = (
    ("Website", "product", "Plan a website delivery from discovery through launch.", ["Discovery", "Design", "Build", "Launch"]),
    ("Mobile App", "product", "Plan an offline-first mobile application release.", ["Research", "Prototype", "Implementation", "Release"]),
    ("College Project", "learning", "Break a college project into research, execution, and submission.", ["Research", "Draft", "Review", "Submission"]),
    ("Startup", "business", "Create a startup execution plan with validation and launch milestones.", ["Validate", "Build", "Launch", "Measure"]),
    ("Marketing Campaign", "marketing", "Plan a measurable marketing campaign.", ["Strategy", "Creative", "Distribution", "Review"]),
    ("Research", "learning", "Structure a research project with evidence and synthesis milestones.", ["Question", "Collect", "Analyze", "Synthesize"]),
    ("Exam Preparation", "learning", "Create a study plan with revision and practice milestones.", ["Syllabus", "Practice", "Revision", "Exam"]),
)


def _not_found(entity: str, entity_id: str) -> HTTPException:
    return HTTPException(status_code=404, detail=f"{entity} '{entity_id}' was not found")


def _apply(instance: Any, values: dict[str, Any]) -> Any:
    for key, value in values.items():
        setattr(instance, key, value)
    return instance


def _queue(db: Session, entity_type: str, entity_id: str, operation: str, payload: dict[str, Any], version: int = 1) -> None:
    db.add(OrganizationSyncQueue(entity_type=entity_type, entity_id=entity_id, operation=operation, payload=payload, version=version))


def _ensure_templates(db: Session) -> None:
    if db.scalar(select(ProjectTemplate.id).limit(1)) is not None:
        return
    for name, category, description, milestones in DEFAULT_TEMPLATES:
        db.add(ProjectTemplate(name=name, category=category, description=description, milestone_names=list(milestones)))
    db.commit()


def _workspace_or_404(db: Session, workspace_id: str) -> Workspace:
    item = db.get(Workspace, workspace_id)
    if item is None:
        raise _not_found("workspace", workspace_id)
    return item


def _project_or_404(db: Session, project_id: str) -> Project:
    item = db.get(Project, project_id)
    if item is None:
        raise _not_found("project", project_id)
    return item


def _goal_or_404(db: Session, goal_id: str) -> Goal:
    item = db.get(Goal, goal_id)
    if item is None:
        raise _not_found("goal", goal_id)
    return item


def _milestone_or_404(db: Session, milestone_id: str) -> Milestone:
    item = db.get(Milestone, milestone_id)
    if item is None:
        raise _not_found("milestone", milestone_id)
    return item


def _project_milestones(db: Session, project_id: str) -> list[Milestone]:
    return list(db.scalars(select(Milestone).where(Milestone.project_id == project_id).order_by(Milestone.deadline, Milestone.created_at)).all())


def _project_goals(db: Session, project: Project) -> list[Goal]:
    linked_ids = set(project.linked_goal_ids or [])
    if not linked_ids:
        return []
    return list(db.scalars(select(Goal).where(Goal.id.in_(linked_ids))).all())


@router.get("/workspaces", response_model=list[WorkspaceRead])
def list_workspaces(include_archived: bool = False, db: Session = Depends(get_db)) -> list[Workspace]:
    statement = select(Workspace).order_by(Workspace.favorite.desc(), Workspace.updated_at.desc())
    if not include_archived:
        statement = statement.where(Workspace.archived.is_(False))
    return list(db.scalars(statement).all())


@router.post("/workspaces", response_model=WorkspaceRead, status_code=status.HTTP_201_CREATED)
def create_workspace(payload: WorkspaceCreate, db: Session = Depends(get_db)) -> Workspace:
    workspace = Workspace(**payload.model_dump())
    db.add(workspace)
    db.flush()
    _queue(db, "workspace", workspace.id, "create", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(workspace)
    return workspace


@router.get("/workspaces/{workspace_id}", response_model=WorkspaceRead)
def get_workspace(workspace_id: str, db: Session = Depends(get_db)) -> Workspace:
    return _workspace_or_404(db, workspace_id)


@router.patch("/workspaces/{workspace_id}", response_model=WorkspaceRead)
def update_workspace(workspace_id: str, payload: WorkspaceUpdate, db: Session = Depends(get_db)) -> Workspace:
    workspace = _workspace_or_404(db, workspace_id)
    _apply(workspace, payload.model_dump(exclude_unset=True))
    db.flush()
    _queue(db, "workspace", workspace.id, "update", payload.model_dump(mode="json", exclude_unset=True))
    db.commit()
    db.refresh(workspace)
    return workspace


@router.delete("/workspaces/{workspace_id}")
def delete_workspace(workspace_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    workspace = _workspace_or_404(db, workspace_id)
    workspace.archived = True
    db.flush()
    _queue(db, "workspace", workspace.id, "archive", {"archived": True})
    db.commit()
    return {"id": workspace_id, "archived": True}


@router.post("/workspaces/{workspace_id}/duplicate", response_model=WorkspaceRead, status_code=status.HTTP_201_CREATED)
def duplicate_workspace(workspace_id: str, db: Session = Depends(get_db)) -> Workspace:
    source = _workspace_or_404(db, workspace_id)
    duplicate = Workspace(name=f"{source.name} Copy", description=source.description, icon=source.icon, cover_image=source.cover_image, color=source.color, owner_id=source.owner_id, ai_context=source.ai_context, settings=dict(source.settings or {}), favorite=False)
    db.add(duplicate)
    db.flush()
    _queue(db, "workspace", duplicate.id, "duplicate", {"source_id": source.id})
    db.commit()
    db.refresh(duplicate)
    return duplicate


@router.get("/workspaces/{workspace_id}/summary", response_model=WorkspaceSummary)
def workspace_summary(workspace_id: str, db: Session = Depends(get_db)) -> WorkspaceSummary:
    workspace = _workspace_or_404(db, workspace_id)
    projects = list(db.scalars(select(Project).where(Project.workspace_id == workspace_id, Project.archived.is_(False))).all())
    goals = list(db.scalars(select(Goal).where(Goal.workspace_id == workspace_id, Goal.archived.is_(False))).all())
    risks = sum(deadline_risk(project, _project_milestones(db, project.id)) in {"high", "medium"} for project in projects)
    average = round(sum(project.progress for project in projects) / len(projects), 1) if projects else 0.0
    return WorkspaceSummary(workspace=workspace, project_count=len(projects), active_project_count=sum(project.status == "active" for project in projects), goal_count=len(goals), deadline_risk_count=risks, average_progress=average)


@router.get("/projects", response_model=list[ProjectRead])
def list_projects(workspace_id: str | None = None, project_status: str | None = Query(default=None, alias="status"), include_archived: bool = False, db: Session = Depends(get_db)) -> list[Project]:
    statement = select(Project).order_by(Project.favorite.desc(), Project.deadline, Project.updated_at.desc())
    if workspace_id:
        statement = statement.where(Project.workspace_id == workspace_id)
    if project_status:
        statement = statement.where(Project.status == project_status)
    if not include_archived:
        statement = statement.where(Project.archived.is_(False))
    return list(db.scalars(statement).all())


@router.post("/projects", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
def create_project(payload: ProjectCreate, db: Session = Depends(get_db)) -> Project:
    _workspace_or_404(db, payload.workspace_id)
    project = Project(**payload.model_dump())
    db.add(project)
    db.flush()
    _queue(db, "project", project.id, "create", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(project)
    return project


@router.get("/projects/{project_id}", response_model=ProjectRead)
def get_project(project_id: str, db: Session = Depends(get_db)) -> Project:
    return _project_or_404(db, project_id)


@router.patch("/projects/{project_id}", response_model=ProjectRead)
def update_project(project_id: str, payload: ProjectUpdate, db: Session = Depends(get_db)) -> Project:
    project = _project_or_404(db, project_id)
    if project.locked and any(key in payload.model_dump(exclude_unset=True) for key in ("name", "description", "status", "progress", "deadline")):
        raise HTTPException(status_code=409, detail="locked projects cannot change core planning fields")
    _apply(project, payload.model_dump(exclude_unset=True))
    db.flush()
    _queue(db, "project", project.id, "update", payload.model_dump(mode="json", exclude_unset=True), version=1)
    db.commit()
    db.refresh(project)
    return project


@router.delete("/projects/{project_id}")
def delete_project(project_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    project = _project_or_404(db, project_id)
    project.archived = True
    project.status = "archived"
    db.flush()
    _queue(db, "project", project.id, "archive", {"archived": True, "status": "archived"})
    db.commit()
    return {"id": project_id, "archived": True}


@router.post("/projects/{project_id}/duplicate", response_model=ProjectRead, status_code=status.HTTP_201_CREATED)
def duplicate_project(project_id: str, db: Session = Depends(get_db)) -> Project:
    source = _project_or_404(db, project_id)
    duplicate = Project(workspace_id=source.workspace_id, name=f"{source.name} Copy", description=source.description, cover=source.cover, icon=source.icon, color=source.color, status="planning", priority=source.priority, start_date=source.start_date, deadline=source.deadline, estimated_minutes=source.estimated_minutes, progress=0, budget=source.budget, tags=list(source.tags or []), category=source.category, owner_id=source.owner_id, linked_goal_ids=list(source.linked_goal_ids or []), linked_task_ids=[], linked_note_ids=[], linked_event_ids=list(source.linked_event_ids or []), linked_asset_ids=list(source.linked_asset_ids or []), linked_reminder_ids=list(source.linked_reminder_ids or []), status_options=list(source.status_options or []), ai_summary="", favorite=False, locked=False)
    db.add(duplicate)
    db.flush()
    _queue(db, "project", duplicate.id, "duplicate", {"source_id": source.id})
    db.commit()
    db.refresh(duplicate)
    return duplicate


@router.get("/projects/{project_id}/dashboard", response_model=ProjectDashboard)
def project_dashboard(project_id: str, db: Session = Depends(get_db)) -> ProjectDashboard:
    project = _project_or_404(db, project_id)
    milestones = _project_milestones(db, project.id)
    goals = _project_goals(db, project)
    task_ids = list(project.linked_task_ids or [])
    task_filters = [TaskModel.id.in_(task_ids)] if task_ids else []
    task_filters.extend([TaskModel.project == project.id, TaskModel.project == project.name])
    tasks = list(db.scalars(select(TaskModel).where(or_(*task_filters), TaskModel.deleted_at.is_(None))).all())
    completed = sum(task.status == "completed" for task in tasks)
    event_ids = list(project.linked_event_ids or [])
    event_filters = [EventModel.id.in_(event_ids)] if event_ids else []
    event_filters.append(EventModel.project_id == project.id)
    calendar_events = list(db.scalars(select(EventModel).where(or_(*event_filters), EventModel.deleted_at.is_(None))).all())
    note_ids = list(project.linked_note_ids or [])
    note_filters = [NoteModel.id.in_(note_ids)] if note_ids else []
    note_filters.append(NoteModel.project_id == project.id)
    notes = list(db.scalars(select(NoteModel).where(or_(*note_filters), NoteModel.deleted.is_(False), NoteModel.archived.is_(False))).all())
    progress = effective_project_progress(project, milestones)
    if milestones and abs(project.progress - progress) > 0.1 and not project.locked:
        project.progress = progress
        db.commit()
        db.refresh(project)
    recommendations = project_recommendations(project, milestones, goals)
    risk = deadline_risk(project, milestones)
    activity = [f"{len(milestones)} milestones tracked", f"{completed} of {len(tasks)} linked tasks completed"]
    if goals:
        activity.append(f"Aligned with {len(goals)} goal(s)")
    return ProjectDashboard(project=project, milestones=milestones, linked_goals=goals, task_count=len(tasks), completed_task_count=completed, calendar_event_count=len(calendar_events), note_count=len(notes), asset_count=len(project.linked_asset_ids or []), reminder_count=len(project.linked_reminder_ids or []), average_milestone_progress=progress, connected_routes={"tasks": "/tasks?project=" + project.id, "calendar": "/calendar?project=" + project.id, "notes": "/notes?project=" + project.id, "analytics": "/analytics?project=" + project.id, "assistant": "/assistant?project=" + project.id}, deadline_risk=risk, recent_activity=activity, ai_summary=project_summary(project, milestones, goals), recommendations=recommendations)


@router.get("/projects/{project_id}/intelligence", response_model=ProjectIntelligence)
def project_intelligence(project_id: str, db: Session = Depends(get_db)) -> ProjectIntelligence:
    project = _project_or_404(db, project_id)
    milestones = _project_milestones(db, project.id)
    goals = _project_goals(db, project)
    risk = deadline_risk(project, milestones)
    return ProjectIntelligence(project_id=project.id, summary=project_summary(project, milestones, goals), deadline_risk=risk, confidence=0.88 if milestones else 0.72, recommendations=project_recommendations(project, milestones, goals), explanation="This local recommendation uses project progress, milestone deadlines, dependencies, linked goals, and completion state. No cloud model or paid API is required.")


@router.get("/goals", response_model=list[GoalRead])
def list_goals(workspace_id: str | None = None, include_archived: bool = False, db: Session = Depends(get_db)) -> list[Goal]:
    statement = select(Goal).order_by(Goal.target_date, Goal.priority, Goal.updated_at.desc())
    if workspace_id:
        statement = statement.where(Goal.workspace_id == workspace_id)
    if not include_archived:
        statement = statement.where(Goal.archived.is_(False))
    return list(db.scalars(statement).all())


@router.post("/goals", response_model=GoalRead, status_code=status.HTTP_201_CREATED)
def create_goal(payload: GoalCreate, db: Session = Depends(get_db)) -> Goal:
    if payload.workspace_id:
        _workspace_or_404(db, payload.workspace_id)
    goal = Goal(**payload.model_dump())
    db.add(goal)
    db.flush()
    _queue(db, "goal", goal.id, "create", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(goal)
    return goal


@router.patch("/goals/{goal_id}", response_model=GoalRead)
def update_goal(goal_id: str, payload: GoalUpdate, db: Session = Depends(get_db)) -> Goal:
    goal = _goal_or_404(db, goal_id)
    if payload.workspace_id:
        _workspace_or_404(db, payload.workspace_id)
    _apply(goal, payload.model_dump(exclude_unset=True))
    db.flush()
    _queue(db, "goal", goal.id, "update", payload.model_dump(mode="json", exclude_unset=True))
    db.commit()
    db.refresh(goal)
    return goal


@router.delete("/goals/{goal_id}")
def delete_goal(goal_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    goal = _goal_or_404(db, goal_id)
    goal.archived = True
    db.flush()
    _queue(db, "goal", goal.id, "archive", {"archived": True})
    db.commit()
    return {"id": goal_id, "archived": True}


@router.get("/projects/{project_id}/milestones", response_model=list[MilestoneRead])
def list_milestones(project_id: str, db: Session = Depends(get_db)) -> list[Milestone]:
    _project_or_404(db, project_id)
    return _project_milestones(db, project_id)


@router.post("/milestones", response_model=MilestoneRead, status_code=status.HTTP_201_CREATED)
def create_milestone(payload: MilestoneCreate, db: Session = Depends(get_db)) -> Milestone:
    _project_or_404(db, payload.project_id)
    milestone = Milestone(**payload.model_dump(), completed=payload.progress >= 100)
    db.add(milestone)
    db.flush()
    _queue(db, "milestone", milestone.id, "create", payload.model_dump(mode="json"))
    db.commit()
    db.refresh(milestone)
    return milestone


@router.patch("/milestones/{milestone_id}", response_model=MilestoneRead)
def update_milestone(milestone_id: str, payload: MilestoneUpdate, db: Session = Depends(get_db)) -> Milestone:
    milestone = _milestone_or_404(db, milestone_id)
    _apply(milestone, payload.model_dump(exclude_unset=True))
    if payload.progress is not None:
        milestone.completed = payload.progress >= 100
    db.flush()
    project = _project_or_404(db, milestone.project_id)
    if not project.locked:
        project.progress = effective_project_progress(project, _project_milestones(db, project.id))
    _queue(db, "milestone", milestone.id, "update", payload.model_dump(mode="json", exclude_unset=True))
    db.commit()
    db.refresh(milestone)
    return milestone


@router.delete("/milestones/{milestone_id}")
def delete_milestone(milestone_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    milestone = _milestone_or_404(db, milestone_id)
    project_id = milestone.project_id
    db.delete(milestone)
    db.flush()
    project = _project_or_404(db, project_id)
    if not project.locked:
        project.progress = effective_project_progress(project, _project_milestones(db, project.id))
    _queue(db, "milestone", milestone_id, "delete", {"project_id": project_id})
    db.commit()
    return {"id": milestone_id, "deleted": True}


@router.get("/templates", response_model=list[ProjectTemplateRead])
def list_templates(db: Session = Depends(get_db)) -> list[ProjectTemplate]:
    _ensure_templates(db)
    return list(db.scalars(select(ProjectTemplate).order_by(ProjectTemplate.name)).all())


@router.post("/templates", response_model=ProjectTemplateRead, status_code=status.HTTP_201_CREATED)
def create_template(payload: ProjectTemplateCreate, db: Session = Depends(get_db)) -> ProjectTemplate:
    template = ProjectTemplate(**payload.model_dump())
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


@router.post("/templates/{template_id}/instantiate", response_model=ProjectDashboard, status_code=status.HTTP_201_CREATED)
def instantiate_template(template_id: str, workspace_id: str = Query(...), db: Session = Depends(get_db)) -> ProjectDashboard:
    _workspace_or_404(db, workspace_id)
    template = db.get(ProjectTemplate, template_id)
    if template is None:
        raise _not_found("template", template_id)
    project = Project(workspace_id=workspace_id, name=template.name, description=template.description, category=template.category, status="planning")
    db.add(project)
    db.flush()
    for position, name in enumerate(template.milestone_names):
        db.add(Milestone(project_id=project.id, name=name, progress=0, dependency_ids=[] if position == 0 else []))
    _queue(db, "project", project.id, "instantiate_template", {"template_id": template.id, "workspace_id": workspace_id})
    db.commit()
    return project_dashboard(project.id, db)


@router.get("/search", response_model=OrganizationSearchResponse)
def search_organization(q: str = Query(min_length=1, max_length=180), workspace_id: str | None = None, search_status: str | None = Query(default=None, alias="status"), category: str | None = None, tag: str | None = None, goal_id: str | None = None, db: Session = Depends(get_db)) -> OrganizationSearchResponse:
    results: list[OrganizationSearchResult] = []
    workspaces = list(db.scalars(select(Workspace).where(Workspace.archived.is_(False))).all())
    projects = list(db.scalars(select(Project).where(Project.archived.is_(False))).all())
    goals = list(db.scalars(select(Goal).where(Goal.archived.is_(False))).all())
    milestones = list(db.scalars(select(Milestone)).all())
    for item in workspaces:
        score = search_score(q, item.name, item.description, item.ai_context)
        if score:
            results.append(OrganizationSearchResult(entity_type="workspace", entity_id=item.id, title=item.name, subtitle=item.description, status="active", route="/organization?workspace=" + item.id, score=score))
    for item in projects:
        if workspace_id and item.workspace_id != workspace_id:
            continue
        if search_status and item.status != search_status:
            continue
        if category and item.category != category:
            continue
        if tag and tag.casefold() not in {value.casefold() for value in (item.tags or [])}:
            continue
        if goal_id and goal_id not in (item.linked_goal_ids or []):
            continue
        score = search_score(q, item.name, item.description, item.category, item.status, " ".join(item.tags or []))
        if score:
            results.append(OrganizationSearchResult(entity_type="project", entity_id=item.id, title=item.name, subtitle=item.description, status=item.status, route="/organization?project=" + item.id, score=score))
    for item in goals:
        if workspace_id and item.workspace_id != workspace_id:
            continue
        score = search_score(q, item.title, item.description, item.category, item.goal_type)
        if score:
            results.append(OrganizationSearchResult(entity_type="goal", entity_id=item.id, title=item.title, subtitle=item.description, status=f"{item.progress:.0f}%", route="/organization?goal=" + item.id, score=score))
    project_ids = {item.id for item in projects if not workspace_id or item.workspace_id == workspace_id}
    for item in milestones:
        if item.project_id not in project_ids:
            continue
        score = search_score(q, item.name)
        if score:
            results.append(OrganizationSearchResult(entity_type="milestone", entity_id=item.id, title=item.name, subtitle=f"{item.progress:.0f}% complete", status="completed" if item.completed else "open", route="/organization?milestone=" + item.id, score=score))
    results.sort(key=lambda item: (-item.score, item.title.casefold()))
    return OrganizationSearchResponse(query=q, results=results[:50])


@router.get("/statistics", response_model=OrganizationStats)
def organization_statistics(db: Session = Depends(get_db)) -> OrganizationStats:
    workspaces = list(db.scalars(select(Workspace).where(Workspace.archived.is_(False))).all())
    projects = list(db.scalars(select(Project).where(Project.archived.is_(False))).all())
    goals = list(db.scalars(select(Goal).where(Goal.archived.is_(False))).all())
    milestones = list(db.scalars(select(Milestone)).all())
    risks = sum(deadline_risk(project, _project_milestones(db, project.id)) in {"high", "medium"} for project in projects)
    return OrganizationStats(workspace_count=len(workspaces), project_count=len(projects), active_project_count=sum(item.status == "active" for item in projects), completed_project_count=sum(item.status == "completed" for item in projects), goal_count=len(goals), milestone_count=len(milestones), deadline_risk_count=risks, average_project_progress=round(sum(item.progress for item in projects) / len(projects), 1) if projects else 0.0)


@router.get("/projects/{project_id}/dependencies", response_model=DependencyCheck)
def project_dependencies(project_id: str, db: Session = Depends(get_db)) -> DependencyCheck:
    project = _project_or_404(db, project_id)
    conflicts = dependency_conflicts(_project_milestones(db, project.id))
    typed = [DependencyConflict(**item) for item in conflicts]
    return DependencyCheck(project_id=project.id, valid=not typed, conflicts=typed, explanation="Dependencies are checked locally for self-links, missing milestones, and cycles before the project critical path is trusted.")


@router.post("/projects/{project_id}/manager-plan", response_model=ProjectManagerPlan)
def project_manager_plan_endpoint(project_id: str, db: Session = Depends(get_db)) -> ProjectManagerPlan:
    project = _project_or_404(db, project_id)
    milestones = _project_milestones(db, project.id)
    goals = _project_goals(db, project)
    task_ids = list(project.linked_task_ids or [])
    task_count = len(db.scalars(select(TaskModel).where(or_(TaskModel.id.in_(task_ids), TaskModel.project == project.id))).all()) if task_ids else len(db.scalars(select(TaskModel).where(TaskModel.project == project.id)).all())
    plan = project_manager_plan(project, milestones, goals, task_count, len(dependency_conflicts(milestones)))
    return ProjectManagerPlan(project_id=project.id, **plan)


@router.post("/projects/{project_id}/chat", response_model=ProjectChatResponse)
def project_chat(project_id: str, payload: ProjectChatRequest, db: Session = Depends(get_db)) -> ProjectChatResponse:
    project = _project_or_404(db, project_id)
    milestones = _project_milestones(db, project.id)
    goals = _project_goals(db, project)
    text = payload.message.casefold()
    summary = project_summary(project, milestones, goals)
    risk = deadline_risk(project, milestones)
    recommendations = project_recommendations(project, milestones, goals)
    actions: list[dict[str, Any]] = []
    if "summar" in text or "status" in text or "progress" in text:
        response = f"{summary} Deadline risk is {risk}. {recommendations[0] if recommendations else 'No further local recommendation is needed.'}"
    elif "block" in text or "risk" in text:
        conflicts = dependency_conflicts(milestones)
        response = f"The current deadline risk is {risk}. " + (f"There are {len(conflicts)} dependency conflict(s) to resolve." if conflicts else "No dependency conflicts were found in the saved milestone graph.")
    elif "milestone" in text:
        response = "The next saved milestone sequence is: " + (", ".join(item.name for item in milestones if not item.completed) or "No incomplete milestones; add the next checkpoint.")
        actions.append({"action": "create_milestone", "label": "Add milestone", "payload": {"project_id": project.id}})
    else:
        response = f"I can summarize {project.name}, inspect blockers, or review milestones locally. {summary}"
    return ProjectChatResponse(project_id=project.id, response=response, explanation="This project chat is a deterministic offline assistant using the project, milestones, dependency graph, linked goals, and current status. It does not send project content to a cloud service.", actions=actions)


@router.get("/projects/{project_id}/export", response_model=ProjectExport)
def export_project(project_id: str, db: Session = Depends(get_db)) -> ProjectExport:
    project = _project_or_404(db, project_id)
    workspace = db.get(Workspace, project.workspace_id)
    milestones = _project_milestones(db, project.id)
    goals = _project_goals(db, project)
    return ProjectExport(exported_at=datetime.now(), workspace=workspace, project=project, milestones=milestones, goals=goals, integrations={"task_ids": project.linked_task_ids or [], "note_ids": project.linked_note_ids or [], "event_ids": project.linked_event_ids or [], "asset_ids": project.linked_asset_ids or [], "reminder_ids": project.linked_reminder_ids or [], "routes": {"tasks": "/tasks?project=" + project.id, "calendar": "/calendar?project=" + project.id, "notes": "/notes?project=" + project.id, "analytics": "/analytics?project=" + project.id, "assistant": "/assistant?project=" + project.id}})


@router.get("/workspaces/{workspace_id}/export")
def export_workspace(workspace_id: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    workspace = _workspace_or_404(db, workspace_id)
    projects = list(db.scalars(select(Project).where(Project.workspace_id == workspace_id)).all())
    goals = list(db.scalars(select(Goal).where(Goal.workspace_id == workspace_id)).all())
    return {"exported_at": datetime.now(), "workspace": workspace, "projects": projects, "goals": goals, "project_count": len(projects), "goal_count": len(goals)}
