import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/features/automation/automation_models.dart';
import 'package:productivity_dashboard/repositories/automation_repository.dart';
import 'package:productivity_dashboard/repositories/task_repository.dart';

void main() {
  test('persists a workflow and executes create-task actions offline',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AutomationRepository(preferences);
    const workflow = AutomationWorkflowModel(
      id: 'workflow-test',
      name: 'Follow up',
      triggerType: 'manual',
      actions: [
        AutomationActionModel(
          actionType: 'create_task',
          label: 'Create next task',
          parameters: {'title': 'Follow up {{event.title}}'},
        ),
      ],
    );

    await repository.createWorkflow(workflow);
    final saved = await repository.loadWorkflows();
    expect(saved.single.name, 'Follow up');
    final execution =
        await repository.runWorkflow(workflow, payload: {'title': 'Planning'});
    expect(execution.status, 'success');
    expect((await TaskRepository(preferences).loadTasks()).single.title,
        'Follow up Planning');
  });

  test('pauses destructive automation for explicit approval', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AutomationRepository(preferences);
    const workflow = AutomationWorkflowModel(
      id: 'workflow-protected',
      name: 'Protected delete',
      triggerType: 'manual',
      actions: [
        AutomationActionModel(
            actionType: 'delete_task', requiresApproval: true),
      ],
    );

    final pending = await repository.runWorkflow(workflow);
    expect(pending.status, 'pending_approval');
    expect(pending.approvalRequired, isTrue);
    expect(
        (await repository.loadExecutions()).single.status, 'pending_approval');
  });

  test('emits matching events and ignores unrelated workflows', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AutomationRepository(preferences);
    const workflow = AutomationWorkflowModel(
      id: 'workflow-event',
      name: 'Task completion note',
      triggerType: 'task_completed',
      actions: [
        AutomationActionModel(
            actionType: 'send_local_notification', label: 'Notify')
      ],
    );
    await repository.createWorkflow(workflow);

    final executions =
        await repository.emitEvent('task_completed', {'title': 'Ship'});
    expect(executions.single.status, 'success');
    expect((await repository.emitEvent('note_created', {})), isEmpty);
  });
}
