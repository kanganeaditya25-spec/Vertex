import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/automation_repository.dart';
import 'automation_models.dart';

final automationControllerProvider =
    AsyncNotifierProvider<AutomationController, AutomationState>(
        AutomationController.new);

class AutomationState {
  const AutomationState(
      {required this.workflows,
      required this.templates,
      required this.executions,
      required this.stats,
      this.selectedWorkflowId,
      this.tab = 'builder'});
  final List<AutomationWorkflowModel> workflows;
  final List<AutomationTemplateModel> templates;
  final List<AutomationExecutionModel> executions;
  final AutomationStatsModel stats;
  final String? selectedWorkflowId;
  final String tab;
  AutomationWorkflowModel? get selectedWorkflow =>
      workflows.where((item) => item.id == selectedWorkflowId).firstOrNull;
  AutomationState copyWith(
          {List<AutomationWorkflowModel>? workflows,
          List<AutomationTemplateModel>? templates,
          List<AutomationExecutionModel>? executions,
          AutomationStatsModel? stats,
          String? selectedWorkflowId,
          String? tab}) =>
      AutomationState(
          workflows: workflows ?? this.workflows,
          templates: templates ?? this.templates,
          executions: executions ?? this.executions,
          stats: stats ?? this.stats,
          selectedWorkflowId: selectedWorkflowId ?? this.selectedWorkflowId,
          tab: tab ?? this.tab);
}

class AutomationController extends AsyncNotifier<AutomationState> {
  AutomationRepository? _repository;
  @override
  Future<AutomationState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = AutomationRepository(preferences);
    final workflows = await _repository!.loadWorkflows();
    return AutomationState(
        workflows: workflows,
        templates: await _repository!.loadTemplates(),
        executions: await _repository!.loadExecutions(),
        stats: await _repository!.loadStats(),
        selectedWorkflowId: workflows.firstOrNull?.id);
  }

  void selectWorkflow(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedWorkflowId: id));
  }

  void selectTab(String tab) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(tab: tab));
  }

  Future<void> createWorkflow(
      {required String name,
      required String triggerType,
      required String actionType,
      String actionLabel = ''}) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || name.trim().isEmpty) return;
    final now = DateTime.now();
    final workflow = AutomationWorkflowModel(
        id: 'workflow-${now.microsecondsSinceEpoch}',
        name: name.trim(),
        triggerType: triggerType,
        workflowType: triggerType == 'manual' ? 'manual' : 'event',
        actions: [
          AutomationActionModel(
              actionType: actionType,
              label: actionLabel.isEmpty ? actionType : actionLabel)
        ],
        createdAt: now,
        updatedAt: now);
    await _repository!.createWorkflow(workflow);
    state = AsyncData(current.copyWith(
        workflows: [...current.workflows, workflow],
        selectedWorkflowId: workflow.id));
  }

  Future<void> saveWorkflow(AutomationWorkflowModel workflow) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    await _repository!.saveWorkflow(workflow);
    state = AsyncData(current.copyWith(
        workflows: current.workflows
            .map((item) => item.id == workflow.id ? workflow : item)
            .toList(),
        selectedWorkflowId: workflow.id));
  }

  Future<AutomationExecutionModel?> runSelected(
      {bool approvalGranted = false}) async {
    final current = state.valueOrNull;
    final workflow = current?.selectedWorkflow;
    if (current == null || workflow == null || _repository == null) return null;
    final execution = await _repository!.runWorkflow(workflow,
        approvalGranted: approvalGranted, payload: {'title': workflow.name});
    state = AsyncData(current.copyWith(
        executions: [execution, ...current.executions],
        stats: await _repository!.loadStats()));
    return execution;
  }

  Future<void> emitEvent(String eventType, Map<String, dynamic> payload) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final executions = await _repository!.emitEvent(eventType, payload);
    state = AsyncData(current.copyWith(
        executions: [...executions, ...current.executions],
        stats: await _repository!.loadStats()));
  }
}
