import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_dashboard/features/dashboard/focusflow_coach.dart';
import 'package:productivity_dashboard/models/dashboard_models.dart';

void main() {
  final now = DateTime(2026, 8, 19, 9);

  DashboardSnapshot snapshotWith(List<TaskSummary> tasks) => DashboardSnapshot(
        userName: 'there',
        tasks: tasks,
        goals: const [],
        events: const [],
        projects: const [],
        habits: const [],
        notes: const [],
        focus: const FocusSummary(),
        lastUpdated: now,
      );

  TaskSummary task(String id, String title,
          {String priority = 'medium',
          DateTime? dueAt,
          int estimatedMinutes = 25,
          String? goalTitle}) =>
      TaskSummary(
        id: id,
        title: title,
        status: 'todo',
        priority: priority,
        dueAt: dueAt,
        estimatedMinutes: estimatedMinutes,
        goalTitle: goalTitle,
      );

  test('chooses overdue work before later tasks', () {
    final result = FocusFlowCoach.recommend(
        snapshotWith([
          task('later', 'Later task',
              priority: 'high', dueAt: now.add(const Duration(days: 2))),
          task('overdue', 'Recover overdue task',
              dueAt: now.subtract(const Duration(hours: 1))),
        ]),
        now: now);

    expect(result.task?.id, 'overdue');
    expect(result.reason, contains('Overdue'));
  });

  test('identifies overload and gives recovery language instead of guilt', () {
    final result = FocusFlowCoach.recommend(
        snapshotWith([
          for (var index = 0; index < 7; index++)
            task('$index', 'Task $index', estimatedMinutes: 45),
        ]),
        now: now);

    expect(result.overloaded, isTrue);
    expect(result.message, contains('rebalance'));
    expect(result.pendingCount, 7);
  });

  test('gives a useful capture prompt when no work is pending', () {
    final result = FocusFlowCoach.recommend(snapshotWith(const []), now: now);

    expect(result.hasMission, isFalse);
    expect(result.message, contains('Capture'));
    expect(result.reason, contains('No unfinished'));
  });
}
