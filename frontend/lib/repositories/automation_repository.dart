import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/automation/automation_models.dart';
import '../features/tasks/task_models.dart';
import 'task_repository.dart';

class AutomationRepository {
  AutomationRepository(this._preferences);
  final SharedPreferences _preferences;
  static const _workflowsKey = 'module9_workflows_v1';
  static const _templatesKey = 'module9_templates_v1';
  static const _executionsKey = 'module9_executions_v1';
  static const _eventsKey = 'module9_events_v1';

  Future<List<AutomationWorkflowModel>> loadWorkflows() async =>
      _load(_workflowsKey, AutomationWorkflowModel.fromJson);
  Future<List<AutomationExecutionModel>> loadExecutions() async =>
      _load(_executionsKey, AutomationExecutionModel.fromJson);

  Future<List<AutomationTemplateModel>> loadTemplates() async {
    final saved = _load(_templatesKey, AutomationTemplateModel.fromJson);
    final templates = await saved;
    if (templates.isNotEmpty) return templates;
    final defaults = _defaultTemplates;
    await _preferences.setString(
        _templatesKey,
        jsonEncode(defaults
            .map((item) => {
                  'id': item.id,
                  'name': item.name,
                  'category': item.category,
                  'description': item.description,
                  'definition': item.definition,
                  'built_in': item.builtIn
                })
            .toList()));
    return defaults;
  }

  Future<AutomationWorkflowModel> createWorkflow(
      AutomationWorkflowModel workflow) async {
    await _saveList(_workflowsKey, [...await loadWorkflows(), workflow],
        (item) => item.toJson());
    return workflow;
  }

  Future<void> saveWorkflow(AutomationWorkflowModel workflow) async {
    await _saveList(
        _workflowsKey,
        (await loadWorkflows())
            .map((item) => item.id == workflow.id ? workflow : item)
            .toList(),
        (item) => item.toJson());
  }

  Future<void> deleteWorkflow(AutomationWorkflowModel workflow) async =>
      saveWorkflow(workflow.copyWith(enabled: false));

  Future<AutomationStatsModel> loadStats() async {
    final workflows = await loadWorkflows();
    final executions = await loadExecutions();
    return AutomationStatsModel(
        workflowCount: workflows.length,
        enabledWorkflowCount: workflows.where((item) => item.enabled).length,
        executionCount: executions.length,
        successCount:
            executions.where((item) => item.status == 'success').length,
        failureCount:
            executions.where((item) => item.status == 'failed').length,
        pendingApprovalCount: executions
            .where((item) => item.status == 'pending_approval')
            .length,
        pendingEventCount: 0);
  }

  Future<AutomationExecutionModel> runWorkflow(AutomationWorkflowModel workflow,
      {Map<String, dynamic> payload = const {},
      bool approvalGranted = false,
      String? replayOf}) async {
    final started = DateTime.now();
    final event = {'event_type': 'manual', ...payload};
    final isDestructive = workflow.actions.any((action) =>
        action.requiresApproval ||
        action.actionType.startsWith('delete_') ||
        action.actionType == 'bulk_delete');
    late AutomationExecutionModel execution;
    if (isDestructive && !approvalGranted) {
      execution = AutomationExecutionModel(
          id: 'execution-${started.microsecondsSinceEpoch}',
          workflowId: workflow.id,
          status: 'pending_approval',
          triggerEvent: event,
          approvalRequired: true,
          replayOf: replayOf,
          startedAt: started,
          finishedAt: DateTime.now());
    } else {
      final logs = <Map<String, dynamic>>[];
      var status = 'success';
      String? error;
      for (final action in [...workflow.actions]
        ..sort((a, b) => a.order.compareTo(b.order))) {
        try {
          logs.add(await _executeAction(action, event));
        } on Object catch (caught) {
          status = 'failed';
          error = '$caught';
          break;
        }
      }
      final finished = DateTime.now();
      execution = AutomationExecutionModel(
          id: 'execution-${started.microsecondsSinceEpoch}',
          workflowId: workflow.id,
          status: status,
          triggerEvent: event,
          actionLogs: logs,
          error: error,
          replayOf: replayOf,
          startedAt: started,
          finishedAt: finished,
          durationMs: finished.difference(started).inMilliseconds);
    }
    await _saveList(
        _executionsKey,
        [execution, ...await loadExecutions()].take(200).toList(),
        (item) => {
              'id': item.id,
              'workflow_id': item.workflowId,
              'status': item.status,
              'trigger_event': item.triggerEvent,
              'action_logs': item.actionLogs,
              'error': item.error,
              'approval_required': item.approvalRequired,
              'replay_of': item.replayOf,
              'attempts': item.attempts,
              'started_at': item.startedAt?.toIso8601String(),
              'finished_at': item.finishedAt?.toIso8601String(),
              'duration_ms': item.durationMs
            });
    return execution;
  }

  Future<List<AutomationExecutionModel>> emitEvent(
      String eventType, Map<String, dynamic> payload) async {
    final workflows = (await loadWorkflows())
        .where((item) =>
            item.enabled &&
            (item.triggerType == eventType ||
                item.triggerType == '*' ||
                item.triggerType == 'all'))
        .toList();
    final executions = <AutomationExecutionModel>[];
    for (final workflow in workflows) {
      if (_conditionsMatch(workflow.conditions, payload)) {
        executions.add(await runWorkflow(workflow,
            payload: {'event_type': eventType, ...payload}));
      }
    }
    final events = _preferences.getStringList(_eventsKey) ?? <String>[];
    events.insert(
        0,
        jsonEncode({
          'event_type': eventType,
          'payload': payload,
          'created_at': DateTime.now().toIso8601String()
        }));
    await _preferences.setStringList(_eventsKey, events.take(200).toList());
    return executions;
  }

  Future<Map<String, dynamic>> _executeAction(
      AutomationActionModel action, Map<String, dynamic> event) async {
    final parameters = action.parameters;
    if (action.actionType == 'create_task') {
      final now = DateTime.now();
      final title = _render(
          '${parameters['title'] ?? parameters['title_template'] ?? action.label.ifEmpty('Automation task')}',
          event);
      final task = TaskModel(
          id: 'automation-task-${now.microsecondsSinceEpoch}',
          title: title,
          description: _render('${parameters['description'] ?? ''}', event),
          status: '${parameters['status'] ?? 'inbox'}',
          priority: '${parameters['priority'] ?? 'medium'}',
          category: '${parameters['category'] ?? 'automation'}',
          project: parameters['project_id'] as String?,
          workspace: parameters['workspace_id'] as String?,
          createdAt: now,
          updatedAt: now,
          aiGenerated: true,
          explanation: 'Created by the offline automation ${action.label}.');
      await TaskRepository(_preferences).create(task);
      return {
        'action': action.actionType,
        'status': 'success',
        'entity_id': task.id,
        'title': title
      };
    }
    return {
      'action': action.actionType,
      'status': 'logged',
      'message': _render(action.label.ifEmpty(action.actionType), event)
    };
  }

  bool _conditionsMatch(List<AutomationConditionModel> conditions,
          Map<String, dynamic> payload) =>
      conditions.every((condition) => _conditionMatches(condition, payload));
  bool _conditionMatches(
      AutomationConditionModel condition, Map<String, dynamic> payload) {
    if (condition.logical == 'AND') {
      return condition.children
          .every((item) => _conditionMatches(item, payload));
    }
    if (condition.logical == 'OR') {
      return condition.children.any((item) => _conditionMatches(item, payload));
    }
    if (condition.logical == 'NOT') {
      return condition.children.isNotEmpty &&
          !_conditionMatches(condition.children.first, payload);
    }
    final actual = payload[condition.field];
    switch (condition.operator) {
      case 'equals':
        return actual == condition.value ||
            '$actual'.toLowerCase() == '${condition.value}'.toLowerCase();
      case 'contains':
        return '$actual'
            .toLowerCase()
            .contains('${condition.value}'.toLowerCase());
      case 'exists':
        return actual != null;
      default:
        return true;
    }
  }

  String _render(String value, Map<String, dynamic> event) {
    var result = value;
    event.forEach(
        (key, value) => result = result.replaceAll('{{event.$key}}', '$value'));
    return result;
  }

  Future<List<T>> _load<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final encoded = _preferences.getString(key);
    if (encoded == null || encoded.isEmpty) return <T>[];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map>()
          .map((item) => fromJson(item.cast<String, dynamic>()))
          .toList();
    } on Object {
      return <T>[];
    }
  }

  Future<void> _saveList<T>(String key, List<T> values,
          Map<String, dynamic> Function(T) toJson) =>
      _preferences.setString(key, jsonEncode(values.map(toJson).toList()));
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

const _defaultTemplates = [
  AutomationTemplateModel(
      id: 'template-daily-planning',
      name: 'Daily Planning',
      category: 'planning',
      description: 'Create a daily planning task.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-weekly-review',
      name: 'Weekly Review',
      category: 'planning',
      description: 'Review completed work weekly.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-project-kickoff',
      name: 'Project Kickoff',
      category: 'projects',
      description: 'Create a kickoff task after a project event.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-study',
      name: 'Study Routine',
      category: 'learning',
      description: 'Create revision work after study.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-deadline',
      name: 'Deadline Follow-up',
      category: 'projects',
      description: 'Notify after a missed deadline.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-meeting',
      name: 'Meeting Preparation',
      category: 'calendar',
      description: 'Prepare before meetings.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-note-backup',
      name: 'Note Backup',
      category: 'notes',
      description: 'Export note snapshots.',
      builtIn: true),
  AutomationTemplateModel(
      id: 'template-habit',
      name: 'Habit Tracking',
      category: 'habits',
      description: 'Create habit follow-up work.',
      builtIn: true),
];
