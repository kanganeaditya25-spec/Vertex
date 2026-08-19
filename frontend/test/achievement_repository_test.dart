import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity_dashboard/features/dashboard/achievement_models.dart';
import 'package:productivity_dashboard/repositories/achievement_repository.dart';

void main() {
  test('completion awards XP and the first-step trophy once', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AchievementRepository(preferences);
    final first = await repository.recordCompletion(
        taskId: 'task-1', completedAt: DateTime(2026, 8, 19, 9));
    final duplicate = await repository.recordCompletion(
        taskId: 'task-1', completedAt: DateTime(2026, 8, 19, 12));

    expect(first.xp, 25);
    expect(first.currentStreak, 1);
    expect(first.trophies, contains('first_step'));
    expect(duplicate.xp, 25);
    expect(duplicate.totalCompletedTasks, 1);
  });

  test('consecutive completion days build streak and unlock trophy', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AchievementRepository(preferences);
    await repository.recordCompletion(
        taskId: 'task-1', completedAt: DateTime(2026, 8, 19, 18));
    await repository.recordCompletion(
        taskId: 'task-2', completedAt: DateTime(2026, 8, 20, 8));
    final profile = await repository.recordCompletion(
        taskId: 'task-3', completedAt: DateTime(2026, 8, 21, 22));

    expect(profile.xp, 75);
    expect(profile.currentStreak, 3);
    expect(profile.bestStreak, 3);
    expect(profile.focusDays, 3);
    expect(profile.trophies, contains('steady_week'));
  });

  test('trophies expose stable definitions for the dashboard', () {
    expect(trophyDefinitions.map((item) => item.id), contains('level_five'));
    expect(trophyDefinitions.map((item) => item.title),
        contains('Momentum Builder'));
  });
}
