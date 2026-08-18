import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/organization_repository.dart';
import 'organization_models.dart';

final organizationControllerProvider =
    AsyncNotifierProvider<OrganizationController, OrganizationState>(
        OrganizationController.new);

class OrganizationState {
  const OrganizationState(
      {required this.workspaces,
      required this.projects,
      required this.goals,
      required this.milestones,
      required this.templates,
      this.selectedWorkspaceId,
      this.selectedProjectId,
      this.projectView = 'dashboard'});
  final List<WorkspaceModel> workspaces;
  final List<ProjectModel> projects;
  final List<GoalModel> goals;
  final List<MilestoneModel> milestones;
  final List<ProjectTemplateModel> templates;
  final String? selectedWorkspaceId;
  final String? selectedProjectId;
  final String projectView;

  WorkspaceModel? get selectedWorkspace =>
      workspaces.where((item) => item.id == selectedWorkspaceId).firstOrNull;
  ProjectModel? get selectedProject =>
      projects.where((item) => item.id == selectedProjectId).firstOrNull;
  List<ProjectModel> get workspaceProjects => projects
      .where(
          (item) => item.workspaceId == selectedWorkspaceId && !item.archived)
      .toList();
  List<GoalModel> get workspaceGoals => goals
      .where(
          (item) => item.workspaceId == selectedWorkspaceId && !item.archived)
      .toList();
  List<MilestoneModel> milestonesFor(String projectId) =>
      milestones.where((item) => item.projectId == projectId).toList();
  double progressFor(ProjectModel project) {
    final items = milestonesFor(project.id);
    return items.isEmpty
        ? project.progress
        : items.map((item) => item.progress).reduce((a, b) => a + b) /
            items.length;
  }

  OrganizationState copyWith(
          {List<WorkspaceModel>? workspaces,
          List<ProjectModel>? projects,
          List<GoalModel>? goals,
          List<MilestoneModel>? milestones,
          List<ProjectTemplateModel>? templates,
          String? selectedWorkspaceId,
          String? selectedProjectId,
          String? projectView}) =>
      OrganizationState(
          workspaces: workspaces ?? this.workspaces,
          projects: projects ?? this.projects,
          goals: goals ?? this.goals,
          milestones: milestones ?? this.milestones,
          templates: templates ?? this.templates,
          selectedWorkspaceId: selectedWorkspaceId ?? this.selectedWorkspaceId,
          selectedProjectId: selectedProjectId ?? this.selectedProjectId,
          projectView: projectView ?? this.projectView);
}

class OrganizationController extends AsyncNotifier<OrganizationState> {
  OrganizationRepository? _repository;
  @override
  Future<OrganizationState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = OrganizationRepository(preferences);
    var workspaces = await _repository!.loadWorkspaces();
    if (workspaces.isEmpty) {
      final now = DateTime.now();
      final personal = WorkspaceModel(
          id: 'workspace-${now.microsecondsSinceEpoch}',
          name: 'Personal',
          description: 'Your private FocusFlow workspace',
          color: '#4F46E5',
          favorite: true,
          createdAt: now,
          updatedAt: now);
      await _repository!.createWorkspace(personal);
      workspaces = [personal];
    }
    final projects = await _repository!.loadProjects();
    return OrganizationState(
        workspaces: workspaces,
        projects: projects,
        goals: await _repository!.loadGoals(),
        milestones: await _repository!.loadMilestones(),
        templates: await _repository!.loadTemplates(),
        selectedWorkspaceId: workspaces.first.id,
        selectedProjectId: projects
            .where((item) =>
                item.workspaceId == workspaces.first.id && !item.archived)
            .firstOrNull
            ?.id);
  }

  void selectWorkspace(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
        selectedWorkspaceId: id,
        selectedProjectId: current.projects
            .where((item) => item.workspaceId == id && !item.archived)
            .firstOrNull
            ?.id));
  }

  void selectProject(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedProjectId: id));
  }

  void selectProjectView(String view) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(projectView: view));
  }

  Future<void> createWorkspace(String name, String description) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || name.trim().isEmpty) return;
    final now = DateTime.now();
    final item = WorkspaceModel(
        id: 'workspace-${now.microsecondsSinceEpoch}',
        name: name.trim(),
        description: description.trim(),
        color: _palette[current.workspaces.length % _palette.length],
        createdAt: now,
        updatedAt: now);
    await _repository!.createWorkspace(item);
    state = AsyncData(current.copyWith(
        workspaces: [...current.workspaces, item],
        selectedWorkspaceId: item.id,
        selectedProjectId: null));
  }

  Future<void> createProject(String name, String description) async {
    final current = state.valueOrNull;
    final workspace = current?.selectedWorkspace;
    if (current == null ||
        workspace == null ||
        _repository == null ||
        name.trim().isEmpty) {
      return;
    }
    final now = DateTime.now();
    final item = ProjectModel(
        id: 'project-${now.microsecondsSinceEpoch}',
        workspaceId: workspace.id,
        name: name.trim(),
        description: description.trim(),
        color: _palette[current.projects.length % _palette.length],
        status: 'planning',
        createdAt: now,
        updatedAt: now);
    await _repository!.createProject(item);
    state = AsyncData(current.copyWith(
        projects: [...current.projects, item], selectedProjectId: item.id));
  }

  Future<void> createGoal(String title, String description) async {
    final current = state.valueOrNull;
    final workspace = current?.selectedWorkspace;
    if (current == null ||
        workspace == null ||
        _repository == null ||
        title.trim().isEmpty) {
      return;
    }
    final item = GoalModel(
        id: 'goal-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        workspaceId: workspace.id,
        description: description.trim(),
        goalType: 'weekly',
        priority: 'high');
    await _repository!.createGoal(item);
    state = AsyncData(current.copyWith(goals: [...current.goals, item]));
  }

  Future<void> createMilestone(String name) async {
    final current = state.valueOrNull;
    final project = current?.selectedProject;
    if (current == null ||
        project == null ||
        _repository == null ||
        name.trim().isEmpty) {
      return;
    }
    final item = MilestoneModel(
        id: 'milestone-${DateTime.now().microsecondsSinceEpoch}',
        projectId: project.id,
        name: name.trim());
    await _repository!.createMilestone(item);
    state =
        AsyncData(current.copyWith(milestones: [...current.milestones, item]));
  }

  Future<void> updateMilestone(MilestoneModel item) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    await _repository!.saveMilestone(item);
    state = AsyncData(current.copyWith(
        milestones: current.milestones
            .map((value) => value.id == item.id ? item : value)
            .toList()));
  }
}

const _palette = [
  '#4F46E5',
  '#0F766E',
  '#B45309',
  '#BE123C',
  '#0369A1',
  '#6D28D9'
];
