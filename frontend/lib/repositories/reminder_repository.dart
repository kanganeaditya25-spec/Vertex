import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/reminders/reminder_models.dart';

class ReminderRepository {
  ReminderRepository(this._preferences);
  static const _remindersKey = 'module12_reminders_v1';
  static const _historyKey = 'module12_reminder_history_v1';
  static const _preferencesKey = 'module12_reminder_preferences_v1';
  final SharedPreferences _preferences;

  Future<List<ReminderModel>> loadReminders() async {
    final raw = _preferences.getStringList(_remindersKey) ?? const [];
    return raw
        .map((value) => ReminderModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map)))
        .toList();
  }

  Future<List<ReminderHistoryModel>> loadHistory() async {
    final raw = _preferences.getStringList(_historyKey) ?? const [];
    return raw
        .map((value) => ReminderHistoryModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map)))
        .toList();
  }

  Future<ReminderPreferencesModel> loadPreferences() async {
    final value = _preferences.getString(_preferencesKey);
    return value == null
        ? const ReminderPreferencesModel()
        : ReminderPreferencesModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map));
  }

  Future<void> savePreferences(ReminderPreferencesModel preferences) async {
    await _preferences.setString(
        _preferencesKey, jsonEncode(preferences.toJson()));
  }

  Future<ReminderModel> create(
      {required String title,
      DateTime? nextTriggerAt,
      String description = '',
      String linkedModule = 'system',
      String linkedItemId = '',
      String category = 'general',
      int priority = 3,
      String triggerType = 'time',
      Map<String, dynamic> repeatRule = const {},
      String notificationType = 'local',
      bool aiGenerated = false,
      String projectId = '',
      String goalId = '',
      String workspaceId = ''}) async {
    final now = DateTime.now();
    final reminder = ReminderModel(
        id: 'reminder-${now.microsecondsSinceEpoch}',
        title: title,
        description: description,
        linkedModule: linkedModule,
        linkedItemId: linkedItemId,
        category: category,
        priority: priority,
        triggerType: triggerType,
        triggerAt: nextTriggerAt,
        nextTriggerAt: nextTriggerAt,
        repeatRule: repeatRule,
        notificationType: notificationType,
        aiGenerated: aiGenerated,
        projectId: projectId,
        goalId: goalId,
        workspaceId: workspaceId,
        createdAt: now,
        modifiedAt: now);
    final reminders = await loadReminders();
    await _saveReminders([...reminders, reminder]);
    await _record(reminder.id, 'created',
        toAt: nextTriggerAt, reason: 'local_create');
    return reminder;
  }

  Future<void> save(ReminderModel reminder,
      {String action = 'updated', String reason = 'local_update'}) async {
    final reminders = await loadReminders();
    final updated = [
      ...reminders.where((item) => item.id != reminder.id),
      reminder.copyWith()
    ];
    await _saveReminders(updated);
    await _record(reminder.id, action,
        reason: reason, toAt: reminder.nextTriggerAt);
  }

  Future<ReminderModel?> get(String id) async {
    for (final reminder in await loadReminders()) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  Future<void> snooze(String id, int minutes) async {
    final reminder = await get(id);
    if (reminder == null) return;
    final base = reminder.nextTriggerAt != null &&
            reminder.nextTriggerAt!.isAfter(DateTime.now())
        ? reminder.nextTriggerAt!
        : DateTime.now();
    await save(
        reminder.copyWith(
            nextTriggerAt: base.add(Duration(minutes: minutes)),
            status: 'scheduled',
            snoozedCount: reminder.snoozedCount + 1),
        action: 'snooze',
        reason: 'snooze_${minutes}m');
  }

  Future<void> complete(String id) async {
    final reminder = await get(id);
    if (reminder == null) return;
    final next = _nextOccurrence(
        reminder.nextTriggerAt ?? DateTime.now(), reminder.repeatRule);
    await save(
        reminder.copyWith(
            nextTriggerAt: next,
            status: next == null ? 'completed' : 'scheduled',
            completedAt: next == null ? DateTime.now() : null),
        action: next == null ? 'completed' : 'completed_recurring',
        reason: 'local_complete');
  }

  Future<void> reschedule(String id, DateTime at) async {
    final reminder = await get(id);
    if (reminder == null) return;
    await save(
        reminder.copyWith(
            triggerAt: at, nextTriggerAt: at, status: 'scheduled'),
        action: 'reschedule',
        reason: 'local_reschedule');
  }

  Future<void> bulkAction(List<String> ids, String action,
      {int snoozeMinutes = 15}) async {
    for (final id in ids) {
      if (action == 'complete') {
        await complete(id);
      } else if (action == 'snooze') {
        await snooze(id, snoozeMinutes);
      } else {
        final reminder = await get(id);
        if (reminder != null) {
          await save(
              reminder.copyWith(
                  status: action == 'delete' ? 'archived' : action),
              action: action,
              reason: 'bulk_$action');
        }
      }
    }
  }

  Future<List<ReminderModel>> due({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final preferences = await loadPreferences();
    return (await loadReminders())
        .where((reminder) =>
            reminder.isActive &&
            reminder.nextTriggerAt != null &&
            !reminder.nextTriggerAt!.isAfter(current) &&
            (!_isQuiet(current, preferences) ||
                reminder.priority == 1 ||
                reminder.notificationType == 'critical'))
        .toList()
      ..sort((a, b) => _score(b, current).compareTo(_score(a, current)));
  }

  Future<List<ReminderModel>> grouped(String group, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    return (await loadReminders())
        .where((reminder) =>
            reminder.status != 'archived' &&
            _groupKey(reminder, group, current) == group)
        .toList();
  }

  Future<ReminderStatsModel> stats() async {
    final reminders = await loadReminders();
    final total = reminders.length;
    final completed =
        reminders.where((item) => item.status == 'completed').length;
    final active = reminders.where((item) => item.isActive).length;
    final dismissed = reminders
        .where((item) => item.status == 'dismissed' || item.status == 'skipped')
        .length;
    final snoozes =
        reminders.fold<int>(0, (sum, item) => sum + item.snoozedCount);
    return ReminderStatsModel(
        total: total,
        active: active,
        completed: completed,
        dismissed: dismissed,
        overdue: reminders.where((item) => item.isOverdue).length,
        snoozeRate: total == 0 ? 0 : snoozes / total,
        completionRate: total == 0 ? 0 : completed / total,
        missedRate: total == 0 ? 0 : dismissed / total);
  }

  Future<void> _saveReminders(List<ReminderModel> reminders) async {
    await _preferences.setStringList(_remindersKey,
        reminders.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<void> _record(String reminderId, String action,
      {DateTime? fromAt, DateTime? toAt, String reason = ''}) async {
    final history = await loadHistory();
    final record = ReminderHistoryModel(
        id: 'history-${DateTime.now().microsecondsSinceEpoch}',
        reminderId: reminderId,
        action: action,
        occurredAt: DateTime.now(),
        fromAt: fromAt,
        toAt: toAt,
        reason: reason);
    final encoded = [...history, record]
        .map((item) => jsonEncode({
              'id': item.id,
              'reminderId': item.reminderId,
              'action': item.action,
              'occurredAt': item.occurredAt.toIso8601String(),
              'fromAt': item.fromAt?.toIso8601String(),
              'toAt': item.toAt?.toIso8601String(),
              'reason': item.reason,
              'metadata': item.metadata
            }))
        .toList();
    await _preferences.setStringList(_historyKey, encoded);
  }
}

DateTime? _nextOccurrence(DateTime at, Map<String, dynamic> rule) {
  final kind = '${rule['kind'] ?? ''}'.toLowerCase();
  final interval = (rule['interval'] as num?)?.toInt() ?? 1;
  if (kind == 'daily') return at.add(Duration(days: interval));
  if (kind == 'weekly') return at.add(Duration(days: 7 * interval));
  if (kind == 'monthly') {
    return DateTime(at.year, at.month + interval, at.day, at.hour, at.minute);
  }
  if (kind == 'yearly') {
    return DateTime(at.year + interval, at.month, at.day, at.hour, at.minute);
  }
  if (kind == 'interval') {
    return at.add(Duration(
        minutes: ((rule['minutes'] as num?)?.toInt() ?? 60) * interval));
  }
  if (kind == 'custom') {
    return at
        .add(Duration(days: ((rule['days'] as num?)?.toInt() ?? 1) * interval));
  }
  return null;
}

bool _isQuiet(DateTime now, ReminderPreferencesModel preferences) {
  if (!preferences.quietHoursEnabled && !preferences.sleepScheduleEnabled) {
    return false;
  }
  final minute = now.hour * 60 + now.minute;
  if (preferences.sleepScheduleEnabled && (minute >= 1320 || minute < 420)) {
    return true;
  }
  if (!preferences.quietHoursEnabled) return false;
  final start = preferences.quietStartMinutes;
  final end = preferences.quietEndMinutes;
  return start > end
      ? minute >= start || minute < end
      : minute >= start && minute < end;
}

double _score(ReminderModel reminder, DateTime now) {
  var score = (6 - reminder.priority) * 20.0 + reminder.snoozedCount * 2.5;
  final trigger = reminder.nextTriggerAt;
  if (trigger != null) {
    final minutes = trigger.difference(now).inMinutes;
    if (minutes < 0) score += 40 + (-minutes / 60).clamp(0, 40).toDouble();
    if (minutes >= 0 && minutes <= 60) score += 30;
  }
  if (reminder.notificationType == 'critical') score += 25;
  return score;
}

String _groupKey(ReminderModel reminder, String group, DateTime now) {
  if (group == 'priority') return 'priority-${reminder.priority}';
  if (group == 'workspace') {
    return reminder.workspaceId.isEmpty ? 'unassigned' : reminder.workspaceId;
  }
  if (group == 'project') {
    return reminder.projectId.isEmpty ? 'unassigned' : reminder.projectId;
  }
  final trigger = reminder.nextTriggerAt;
  if (trigger == null) return 'unscheduled';
  if (trigger.isBefore(DateTime(now.year, now.month, now.day))) {
    return 'overdue';
  }
  if (trigger.year == now.year &&
      trigger.month == now.month &&
      trigger.day == now.day) {
    return 'today';
  }
  final tomorrow = now.add(const Duration(days: 1));
  if (trigger.year == tomorrow.year &&
      trigger.month == tomorrow.month &&
      trigger.day == tomorrow.day) {
    return 'tomorrow';
  }
  return 'later';
}

extension ReminderSuggestions on ReminderRepository {
  Future<List<SmartSuggestionModel>> smartSuggestions() async {
    final reminders = await loadReminders();
    final history = await loadHistory();
    final suggestions = <SmartSuggestionModel>[];
    for (final reminder in reminders.where((item) => item.isActive)) {
      final snoozes = history
          .where((item) =>
              item.reminderId == reminder.id && item.action == 'snooze')
          .length;
      if (snoozes >= 2 && reminder.nextTriggerAt != null) {
        suggestions.add(SmartSuggestionModel(
            reminderId: reminder.id,
            recommendation: 'Move reminder one hour later',
            reason:
                'This reminder was snoozed $snoozes times; a later time may reduce interruption.',
            suggestedTriggerAt:
                reminder.nextTriggerAt!.add(const Duration(hours: 1)),
            confidence: (0.55 + snoozes * 0.08).clamp(0, 0.95).toDouble()));
      } else if (reminder.isOverdue && reminder.priority <= 2) {
        suggestions.add(SmartSuggestionModel(
            reminderId: reminder.id,
            recommendation: 'Schedule a near-term catch-up',
            reason: 'This high-priority reminder is overdue and still active.',
            suggestedTriggerAt: DateTime.now().add(const Duration(minutes: 15)),
            confidence: 0.82));
      }
    }
    return suggestions;
  }
}
