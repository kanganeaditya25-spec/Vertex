import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/analytics_repository.dart';
import 'analytics_models.dart';

final analyticsControllerProvider =
    AsyncNotifierProvider<AnalyticsController, AnalyticsState>(
        AnalyticsController.new);

class AnalyticsState {
  const AnalyticsState({required this.dashboard, this.period = 'weekly'});
  final AnalyticsDashboardModel dashboard;
  final String period;
  AnalyticsState copyWith(
          {AnalyticsDashboardModel? dashboard, String? period}) =>
      AnalyticsState(
          dashboard: dashboard ?? this.dashboard,
          period: period ?? this.period);
}

class AnalyticsController extends AsyncNotifier<AnalyticsState> {
  AnalyticsRepository? _repository;

  @override
  Future<AnalyticsState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = AnalyticsRepository(preferences);
    const period = 'weekly';
    return AnalyticsState(
        dashboard: await _repository!.loadDashboard(period: period),
        period: period);
  }

  Future<void> setPeriod(String period) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => current.copyWith(
        period: period,
        dashboard: await _repository!.loadDashboard(period: period)));
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return;
    }
    state = await AsyncValue.guard(() async => current.copyWith(
        dashboard: await _repository!.loadDashboard(period: current.period)));
  }

  Future<void> saveFocusSession(int minutes,
      {String sessionType = 'deep_work'}) async {
    if (_repository == null || minutes <= 0) {
      return;
    }
    await _repository!
        .saveFocusSession(minutes: minutes, sessionType: sessionType);
    await refresh();
  }
}
