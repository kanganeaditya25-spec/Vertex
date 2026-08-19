import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/achievement_repository.dart';
import 'achievement_models.dart';

final achievementProfileProvider =
    AsyncNotifierProvider<AchievementController, AchievementProfile>(
        AchievementController.new);

class AchievementController extends AsyncNotifier<AchievementProfile> {
  AchievementRepository? _repository;

  @override
  Future<AchievementProfile> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = AchievementRepository(preferences);
    return _repository!.load();
  }

  Future<AchievementProfile> recordCompletion({
    required String taskId,
    DateTime? completedAt,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return state.valueOrNull ?? const AchievementProfile();
    }

    final next = await repository.recordCompletion(
        taskId: taskId, completedAt: completedAt);
    state = AsyncData(next);
    return next;
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) return;
    state = AsyncData(await repository.load());
  }
}
