import 'package:flutter_test/flutter_test.dart';

import '../lib/models/dashboard_models.dart';

void main() {
  test('empty dashboard snapshot is safe for offline startup', () {
    final snapshot = DashboardSnapshot.empty();

    expect(snapshot.userName, 'there');
    expect(snapshot.tasks, isEmpty);
    expect(snapshot.goals, isEmpty);
    expect(snapshot.focus.isRunning, isFalse);
  });

  test('dashboard snapshot round-trips through JSON', () {
    final original = DashboardSnapshot(
      userName: 'Aditya',
      tasks: [const TaskSummary(id: 't1', title: 'Plan the day', status: 'todo', priority: 'high', estimatedMinutes: 30)],
      goals: [const GoalSummary(id: 'g1', title: 'Build consistency', progress: 0.4, linkedTaskCount: 2, completedTaskCount: 1)],
      events: const [],
      projects: const [],
      habits: const [],
      notes: const [],
      focus: const FocusSummary(todaySeconds: 900),
      lastUpdated: DateTime.utc(2026, 8, 18),
    );

    final decoded = DashboardSnapshot.fromJson(original.toJson());

    expect(decoded.userName, 'Aditya');
    expect(decoded.tasks.single.title, 'Plan the day');
    expect(decoded.goals.single.completedTaskCount, 1);
    expect(decoded.focus.todaySeconds, 900);
  });
}
