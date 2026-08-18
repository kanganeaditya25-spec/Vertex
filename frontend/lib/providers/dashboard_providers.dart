import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_models.dart';
import '../repositories/dashboard_repository.dart';
import '../services/dashboard_api_service.dart';

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
        DashboardController.new);

class DashboardState {
  const DashboardState(
      {required this.snapshot,
      required this.preferences,
      this.localAiAvailable = false});

  final DashboardSnapshot snapshot;
  final DashboardPreferences preferences;
  final bool localAiAvailable;

  DashboardState copyWith({
    DashboardSnapshot? snapshot,
    DashboardPreferences? preferences,
    bool? localAiAvailable,
  }) =>
      DashboardState(
        snapshot: snapshot ?? this.snapshot,
        preferences: preferences ?? this.preferences,
        localAiAvailable: localAiAvailable ?? this.localAiAvailable,
      );
}

class DashboardController extends AsyncNotifier<DashboardState> {
  DashboardRepository? _repository;
  DashboardApiService? _apiService;
  Timer? _focusTimer;

  @override
  Future<DashboardState> build() async {
    ref.onDispose(() => _focusTimer?.cancel());
    final sharedPreferences = await SharedPreferences.getInstance();
    _repository = DashboardRepository(sharedPreferences);
    _apiService = DashboardApiService(sharedPreferences);
    final localSnapshot = await _repository!.loadSnapshot();
    final preferences = _repository!.loadPreferences();
    final syncedSnapshot = await _apiService!.trySync(localSnapshot);
    if (syncedSnapshot != null) {
      await _repository!.saveSnapshot(syncedSnapshot);
    }
    return DashboardState(
        snapshot: syncedSnapshot ?? localSnapshot, preferences: preferences);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final localSnapshot = await _repository!.loadSnapshot();
    final syncedSnapshot = await _apiService?.trySync(localSnapshot);
    final snapshot = syncedSnapshot ?? localSnapshot;
    if (syncedSnapshot != null) {
      await _repository!.saveSnapshot(syncedSnapshot);
    }
    state = AsyncData(current.copyWith(snapshot: snapshot));
  }

  Future<void> startFocus() async {
    final current = state.valueOrNull;
    if (current == null || current.snapshot.focus.isRunning) return;

    final started = current.snapshot.copyWith(
      focus: current.snapshot.focus.copyWith(isRunning: true, isPaused: false),
      lastUpdated: DateTime.now(),
    );
    state = AsyncData(current.copyWith(snapshot: started));
    await _persist();

    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final live = state.valueOrNull;
      if (live == null ||
          !live.snapshot.focus.isRunning ||
          live.snapshot.focus.isPaused) {
        return;
      }
      final nextFocus = live.snapshot.focus.copyWith(
        elapsedSeconds: live.snapshot.focus.elapsedSeconds + 1,
        todaySeconds: live.snapshot.focus.todaySeconds + 1,
        longestSessionSeconds: live.snapshot.focus.longestSessionSeconds <
                live.snapshot.focus.elapsedSeconds + 1
            ? live.snapshot.focus.elapsedSeconds + 1
            : live.snapshot.focus.longestSessionSeconds,
      );
      state = AsyncData(live.copyWith(
          snapshot: live.snapshot
              .copyWith(focus: nextFocus, lastUpdated: DateTime.now())));
    });
  }

  Future<void> pauseFocus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      snapshot: current.snapshot
          .copyWith(focus: current.snapshot.focus.copyWith(isPaused: true)),
    ));
    await _persist();
  }

  Future<void> resumeFocus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      snapshot: current.snapshot
          .copyWith(focus: current.snapshot.focus.copyWith(isPaused: false)),
    ));
    await _persist();
  }

  Future<void> stopFocus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    _focusTimer?.cancel();
    state = AsyncData(current.copyWith(
      snapshot: current.snapshot.copyWith(
        focus: current.snapshot.focus
            .copyWith(isRunning: false, isPaused: false, elapsedSeconds: 0),
      ),
    ));
    await _persist();
  }

  Future<void> toggleWidget(String widgetId) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final visible = [...current.preferences.visibleWidgets];
    if (visible.contains(widgetId)) {
      visible.remove(widgetId);
    } else {
      visible.add(widgetId);
    }
    final preferences = DashboardPreferences(
        visibleWidgets: visible,
        pinnedWidgets: current.preferences.pinnedWidgets);
    state = AsyncData(current.copyWith(preferences: preferences));
    await _repository!.savePreferences(preferences);
  }

  Future<void> resetLayout() async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final preferences = DashboardPreferences.defaults();
    state = AsyncData(current.copyWith(preferences: preferences));
    await _repository!.savePreferences(preferences);
  }

  Future<void> _persist() async {
    final current = state.valueOrNull;
    if (current != null && _repository != null) {
      await _repository!.saveSnapshot(current.snapshot);
    }
  }
}

class DashboardStatistics {
  const DashboardStatistics(
      {required this.totalTasks,
      required this.completedTasks,
      required this.pendingTasks,
      required this.completionRate});

  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final double completionRate;
}

final dashboardProvider = dashboardControllerProvider;

final greetingProvider = Provider<String>((ref) {
  final snapshot =
      ref.watch(dashboardControllerProvider).valueOrNull?.snapshot ??
          DashboardSnapshot.empty();
  final hour = DateTime.now().hour;
  final greeting = hour < 12
      ? 'Good morning'
      : hour < 18
          ? 'Good afternoon'
          : 'Good evening';
  return '$greeting, ${snapshot.userName}';
});

final analyticsProvider = Provider<List<TaskSummary>>((ref) {
  return ref.watch(dashboardControllerProvider).valueOrNull?.snapshot.tasks ??
      const [];
});

final quickActionProvider = Provider<List<String>>((ref) =>
    const ['start_focus', 'new_task', 'new_note', 'event', 'voice_command']);

final recentActivityProvider = Provider<List<NoteSummary>>((ref) {
  return ref.watch(dashboardControllerProvider).valueOrNull?.snapshot.notes ??
      const [];
});

final aiInsightProvider = Provider<bool>((ref) {
  return ref.watch(dashboardControllerProvider).valueOrNull?.localAiAvailable ??
      false;
});

final widgetProvider = Provider<DashboardPreferences>((ref) {
  return ref.watch(dashboardControllerProvider).valueOrNull?.preferences ??
      DashboardPreferences.defaults();
});

final statisticsProvider = Provider<DashboardStatistics>((ref) {
  final tasks =
      ref.watch(dashboardControllerProvider).valueOrNull?.snapshot.tasks ??
          const [];
  final completed = tasks.where((task) => task.isCompleted).length;
  return DashboardStatistics(
    totalTasks: tasks.length,
    completedTasks: completed,
    pendingTasks: tasks.length - completed,
    completionRate: tasks.isEmpty ? 0 : completed / tasks.length,
  );
});

final notificationProvider = Provider<int>((ref) => 0);

final focusProvider = Provider<FocusSummary>((ref) {
  return ref.watch(dashboardControllerProvider).valueOrNull?.snapshot.focus ??
      const FocusSummary();
});
