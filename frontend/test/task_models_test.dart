import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_dashboard/features/tasks/task_models.dart';

void main() {
  test('rich task round-trips with checklist and intelligence metadata', () {
    final now = DateTime.utc(2026, 8, 19, 9);
    final task = TaskModel(
      id: 'task-1',
      title: 'Prepare release notes',
      priority: 'urgent',
      category: 'work',
      tags: ['release', 'writing'],
      checklist: [
        const ChecklistItem(
            id: 'item-1', text: 'Collect changes', completed: true),
        const ChecklistItem(id: 'item-2', text: 'Publish notes'),
      ],
      aiScore: 83,
      riskScore: 42,
      createdAt: now,
      updatedAt: now,
    );

    final decoded = TaskModel.fromJson(task.toJson());
    expect(decoded.title, task.title);
    expect(decoded.tags, task.tags);
    expect(decoded.checklistCompleted, 1);
    expect(decoded.checklistProgress, 50);
    expect(decoded.aiScore, 83);
    expect(decoded.riskScore, 42);
  });
}
