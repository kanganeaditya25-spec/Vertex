import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/dashboard/achievement_models.dart';

class AchievementRepository {
  AchievementRepository(this._preferences);

  final SharedPreferences _preferences;
  static const _key = 'focusflow_achievements_v1';

  Future<AchievementProfile> load() async {
    final encoded = _preferences.getString(_key);
    if (encoded == null || encoded.isEmpty) return const AchievementProfile();
    try {
      return AchievementProfile.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return const AchievementProfile();
    }
  }

  Future<void> save(AchievementProfile profile) async {
    await _preferences.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<AchievementProfile> recordCompletion({
    required String taskId,
    DateTime? completedAt,
    int baseXp = 25,
  }) async {
    final current = await load();
    if (current.completedTaskIds.contains(taskId)) return current;
    final date = completedAt ?? DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateKey = achievementDate(normalizedDate);
    final dates = {...current.completionDates, dateKey}.toList()..sort();
    final previousDate = current.lastCompletionDate;
    final previousDay = previousDate == null
        ? null
        : DateTime(previousDate.year, previousDate.month, previousDate.day);
    final consecutive = previousDay != null &&
        achievementDate(previousDay) != dateKey &&
        normalizedDate.difference(previousDay) == const Duration(days: 1);
    final streak = previousDate == null
        ? 1
        : achievementDate(previousDate) == dateKey
            ? current.currentStreak
            : consecutive
                ? current.currentStreak + 1
                : 1;
    final xp = current.xp + baseXp;
    final completed = [...current.completedTaskIds, taskId];
    final trophies = {...current.trophies};
    for (final trophy in trophyDefinitions) {
      final achieved = switch (trophy.id) {
        'first_step' => completed.length >= trophy.threshold,
        'steady_week' => streak >= trophy.threshold,
        'ten_tasks' => completed.length >= trophy.threshold,
        'focused_month' => dates.length >= trophy.threshold,
        'level_five' => xp >= trophy.threshold,
        _ => false,
      };
      if (achieved) trophies.add(trophy.id);
    }
    final next = current.copyWith(
      xp: xp,
      currentStreak: streak,
      bestStreak: streak > current.bestStreak ? streak : current.bestStreak,
      totalCompletedTasks: completed.length,
      focusDays: dates.length,
      lastCompletionDate: normalizedDate,
      completionDates: dates,
      completedTaskIds: completed,
      trophies: trophies.toList(),
    );
    await save(next);
    return next;
  }
}
