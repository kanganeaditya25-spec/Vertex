import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/organization/organization_models.dart';

class OrganizationRepository {
  OrganizationRepository(this._preferences);
  final SharedPreferences _preferences;
  static const _workspacesKey = 'module7_workspaces_v1';
  static const _projectsKey = 'module7_projects_v1';
  static const _goalsKey = 'module7_goals_v1';
  static const _milestonesKey = 'module7_milestones_v1';
  static const _templatesKey = 'module7_templates_v1';
  static const _queueKey = 'module7_sync_queue_v1';

  Future<List<WorkspaceModel>> loadWorkspaces() async =>
      _load(_workspacesKey, WorkspaceModel.fromJson);
  Future<List<ProjectModel>> loadProjects() async =>
      _load(_projectsKey, ProjectModel.fromJson);
  Future<List<GoalModel>> loadGoals() async =>
      _load(_goalsKey, GoalModel.fromJson);
  Future<List<MilestoneModel>> loadMilestones() async =>
      _load(_milestonesKey, MilestoneModel.fromJson);
  Future<List<ProjectTemplateModel>> loadTemplates() async =>
      _load(_templatesKey, ProjectTemplateModel.fromJson);

  Future<WorkspaceModel> createWorkspace(WorkspaceModel item) async {
    final next = item;
    await _upsert(_workspacesKey, await loadWorkspaces(), next,
        (value) => value.id, (value) => value.toJson());
    await _queue('workspace', next.id, 'create', next.toJson());
    return next;
  }

  Future<ProjectModel> createProject(ProjectModel item) async {
    final next = item;
    await _upsert(_projectsKey, await loadProjects(), next, (value) => value.id,
        (value) => value.toJson());
    await _queue('project', next.id, 'create', next.toJson());
    return next;
  }

  Future<GoalModel> createGoal(GoalModel item) async {
    final next = item;
    await _upsert(_goalsKey, await loadGoals(), next, (value) => value.id,
        (value) => value.toJson());
    await _queue('goal', next.id, 'create', next.toJson());
    return next;
  }

  Future<MilestoneModel> createMilestone(MilestoneModel item) async {
    final next = item;
    await _upsert(_milestonesKey, await loadMilestones(), next,
        (value) => value.id, (value) => value.toJson());
    await _queue('milestone', next.id, 'create', next.toJson());
    return next;
  }

  Future<void> saveWorkspace(WorkspaceModel item) async {
    await _replace(
        _workspacesKey,
        (await loadWorkspaces())
            .map((value) => value.id == item.id ? item : value)
            .toList(),
        (value) => value.toJson());
    await _queue('workspace', item.id, 'update', item.toJson());
  }

  Future<void> saveProject(ProjectModel item) async {
    await _replace(
        _projectsKey,
        (await loadProjects())
            .map((value) => value.id == item.id ? item : value)
            .toList(),
        (value) => value.toJson());
    await _queue('project', item.id, 'update', item.toJson());
  }

  Future<void> saveGoal(GoalModel item) async {
    await _replace(
        _goalsKey,
        (await loadGoals())
            .map((value) => value.id == item.id ? item : value)
            .toList(),
        (value) => value.toJson());
    await _queue('goal', item.id, 'update', item.toJson());
  }

  Future<void> saveMilestone(MilestoneModel item) async {
    await _replace(
        _milestonesKey,
        (await loadMilestones())
            .map((value) => value.id == item.id ? item : value)
            .toList(),
        (value) => value.toJson());
    await _queue('milestone', item.id, 'update', item.toJson());
  }

  Future<List<Map<String, dynamic>>> loadQueue() async {
    final value = _preferences.getString(_queueKey);
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _queue(String entityType, String entityId, String operation,
      Map<String, dynamic> payload) async {
    final queue = await loadQueue();
    queue.add({
      'id': '$entityId:$operation:${DateTime.now().microsecondsSinceEpoch}',
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String()
    });
    await _preferences.setString(_queueKey, jsonEncode(queue));
  }

  Future<List<T>> _load<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final value = _preferences.getString(key);
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _upsert<T>(String key, List<T> values, T next,
      String Function(T) id, Map<String, dynamic> Function(T) toJson) async {
    await _replace(
        key, [...values.where((value) => id(value) != id(next)), next], toJson);
  }

  Future<void> _replace<T>(String key, List<T> values,
          Map<String, dynamic> Function(T) toJson) async =>
      _preferences.setString(key, jsonEncode(values.map(toJson).toList()));
}
