import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/settings_repository.dart';
import 'settings_models.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

class SettingsState {
  const SettingsState({
    required this.snapshot,
    required this.backups,
    this.storage = const StorageStatsModel(),
    this.selectedCategory = 'general',
    this.searchQuery = '',
  });
  final SettingsSnapshotModel snapshot;
  final List<BackupModel> backups;
  final StorageStatsModel storage;
  final String selectedCategory;
  final String searchQuery;

  dynamic get themeMode => snapshot.valueAt('appearance.theme_mode', 'system');
  String get accentColor =>
      '${snapshot.valueAt('appearance.accent_color', 'indigo')}';
  double get fontScale =>
      (snapshot.valueAt('appearance.font_scale', 1.0) as num).toDouble();

  SettingsState copyWith({
    SettingsSnapshotModel? snapshot,
    List<BackupModel>? backups,
    StorageStatsModel? storage,
    String? selectedCategory,
    String? searchQuery,
  }) =>
      SettingsState(
        snapshot: snapshot ?? this.snapshot,
        backups: backups ?? this.backups,
        storage: storage ?? this.storage,
        selectedCategory: selectedCategory ?? this.selectedCategory,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

class SettingsController extends AsyncNotifier<SettingsState> {
  SettingsRepository? _repository;

  @override
  Future<SettingsState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = SettingsRepository(preferences);
    return SettingsState(
      snapshot: await _repository!.load(),
      backups: await _repository!.loadBackups(),
    );
  }

  Future<void> updateSetting(String path, dynamic value) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return;
    }
    final snapshot = await _repository!.patch(path, value);
    state = AsyncData(current.copyWith(snapshot: snapshot));
  }

  Future<void> selectCategory(String category) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(selectedCategory: category));
    }
  }

  Future<void> setSearchQuery(String query) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(searchQuery: query));
    }
  }

  Future<BackupModel?> createBackup({
    String label = 'Manual local backup',
  }) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return null;
    }
    final backup = await _repository!.createLocalBackup(label: label);
    state = AsyncData(
      current.copyWith(
        backups: await _repository!.loadBackups(),
        snapshot: await _repository!.load(),
      ),
    );
    return backup;
  }

  Future<void> restoreBackup(String id) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return;
    }
    final snapshot = await _repository!.restoreLocalBackup(id);
    state = AsyncData(current.copyWith(snapshot: snapshot));
  }

  Future<void> privacyAction(String action) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return;
    }
    if (action == 'clear_search_history') {
      await _repository!.clearSearchHistory();
    }
    if (action == 'clear_ai_memory') {
      await _repository!.clearAiMemory();
    }
    if (action == 'clear_cache') {
      await _repository!.clearCache();
    }
    state = AsyncData(current.copyWith(snapshot: await _repository!.load()));
  }

  Future<String> exportSettings() async => _repository?.exportJson() ?? '{}';
  Future<void> importSettings(String payload) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) {
      return;
    }
    state = AsyncData(
        current.copyWith(snapshot: await _repository!.importJson(payload)));
  }
}
