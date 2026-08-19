import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/reminder_repository.dart';
import 'reminder_models.dart';
import 'reminder_worker.dart';

final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, ReminderState>(
        ReminderController.new);

class ReminderState {
  const ReminderState(
      {required this.reminders,
      required this.history,
      required this.preferences,
      required this.stats,
      this.query = '',
      this.filter = 'active',
      this.selectedIds = const [],
      this.smartSuggestions = const [],
      this.deliveredCount = 0});
  final List<ReminderModel> reminders;
  final List<ReminderHistoryModel> history;
  final ReminderPreferencesModel preferences;
  final ReminderStatsModel stats;
  final String query;
  final String filter;
  final List<String> selectedIds;
  final List<SmartSuggestionModel> smartSuggestions;
  final int deliveredCount;

  List<ReminderModel> get visibleReminders => visibleRemindersFor(null);

  List<ReminderModel> visibleRemindersFor(String? projectId) =>
      reminders.where((reminder) {
        if (filter == 'active' && !reminder.isActive) return false;
        if (filter == 'today') {
          final date = reminder.nextTriggerAt;
          final now = DateTime.now();
          if (date == null ||
              date.year != now.year ||
              date.month != now.month ||
              date.day != now.day) {
            return false;
          }
        }
        if (filter == 'overdue' && !reminder.isOverdue) return false;
        if (filter == 'completed' && reminder.status != 'completed') {
          return false;
        }
        if (filter == 'dismissed' &&
            reminder.status != 'dismissed' &&
            reminder.status != 'skipped') {
          return false;
        }
        if (filter == 'history' && reminder.isActive) {
          return false;
        }
        if (projectId != null && reminder.projectId != projectId) {
          return false;
        }
        if (query.trim().isEmpty) return true;
        final text = [
          reminder.title,
          reminder.description,
          reminder.category,
          reminder.linkedModule,
          reminder.sourceRule
        ].join(' ').toLowerCase();
        return text.contains(query.trim().toLowerCase());
      }).toList();

  ReminderState copyWith(
          {List<ReminderModel>? reminders,
          List<ReminderHistoryModel>? history,
          ReminderPreferencesModel? preferences,
          ReminderStatsModel? stats,
          String? query,
          String? filter,
          List<String>? selectedIds,
          List<SmartSuggestionModel>? smartSuggestions,
          int? deliveredCount}) =>
      ReminderState(
          reminders: reminders ?? this.reminders,
          history: history ?? this.history,
          preferences: preferences ?? this.preferences,
          stats: stats ?? this.stats,
          query: query ?? this.query,
          filter: filter ?? this.filter,
          selectedIds: selectedIds ?? this.selectedIds,
          smartSuggestions: smartSuggestions ?? this.smartSuggestions,
          deliveredCount: deliveredCount ?? this.deliveredCount);
}

class ReminderController extends AsyncNotifier<ReminderState> {
  ReminderRepository? _repository;
  ReminderWorker? _worker;
  final LocalNotificationService _notifications = LocalNotificationService();

  @override
  Future<ReminderState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = ReminderRepository(preferences);
    _worker = ReminderWorker(_repository!, _notifications);
    ref.onDispose(() => _worker?.dispose());
    _worker!.start((_) async => refresh());
    return _loadState();
  }

  Future<ReminderState> _loadState({ReminderState? current}) async {
    final reminders = await _repository!.loadReminders();
    return (current ??
            const ReminderState(
                reminders: [],
                history: [],
                preferences: ReminderPreferencesModel(),
                stats: ReminderStatsModel()))
        .copyWith(
            reminders: reminders,
            history: await _repository!.loadHistory(),
            preferences: await _repository!.loadPreferences(),
            stats: await _repository!.stats(),
            smartSuggestions: await _repository!.smartSuggestions(),
            deliveredCount: _notifications.delivered.length);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    state = AsyncData(await _loadState(current: current));
  }

  Future<void> create(
      {required String title,
      DateTime? nextTriggerAt,
      String description = '',
      String linkedModule = 'system',
      int priority = 3,
      String category = 'general',
      String triggerType = 'time',
      Map<String, dynamic> repeatRule = const {},
      String projectId = ''}) async {
    if (_repository == null) return;
    await _repository!.create(
        title: title,
        nextTriggerAt: nextTriggerAt,
        description: description,
        linkedModule: linkedModule,
        priority: priority,
        category: category,
        triggerType: triggerType,
        repeatRule: repeatRule,
        projectId: projectId);
    await refresh();
  }

  Future<void> complete(String id) async {
    await _repository?.complete(id);
    await refresh();
  }

  Future<void> snooze(String id, int minutes) async {
    await _repository?.snooze(id, minutes);
    await refresh();
  }

  Future<void> reschedule(String id, DateTime at) async {
    await _repository?.reschedule(id, at);
    await refresh();
  }

  Future<void> bulkAction(String action) async {
    final current = state.valueOrNull;
    if (_repository == null || current == null || current.selectedIds.isEmpty) {
      return;
    }
    await _repository!.bulkAction(current.selectedIds, action);
    state = AsyncData(
        (await _loadState(current: current)).copyWith(selectedIds: const []));
  }

  Future<void> savePreferences(ReminderPreferencesModel preferences) async {
    await _repository?.savePreferences(preferences);
    await refresh();
  }

  void setQuery(String query) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(query: query));
  }

  void setFilter(String filter) {
    final current = state.valueOrNull;
    if (current != null) {
      state =
          AsyncData(current.copyWith(filter: filter, selectedIds: const []));
    }
  }

  void toggleSelection(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    final selected = current.selectedIds.contains(id)
        ? current.selectedIds.where((value) => value != id).toList()
        : [...current.selectedIds, id];
    state = AsyncData(current.copyWith(selectedIds: selected));
  }

  void clearSelection() {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(selectedIds: const []));
    }
  }
}
