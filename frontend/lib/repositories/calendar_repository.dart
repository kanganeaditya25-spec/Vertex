import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_models.dart';

class CalendarRepository {
  CalendarRepository(this._preferences);

  final SharedPreferences _preferences;
  static const _eventsKey = 'module4_calendar_events_v1';
  static const _preferencesKey = 'module4_calendar_preferences_v1';
  static const _queueKey = 'module4_calendar_sync_queue_v1';

  Future<List<CalendarEvent>> loadEvents() async {
    final encoded = _preferences.getString(_eventsKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final list = jsonDecode(encoded) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CalendarEvent.fromJson)
          .where((event) => event.status != 'deleted')
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<CalendarPreferences> loadPreferences() async {
    final encoded = _preferences.getString(_preferencesKey);
    if (encoded == null || encoded.isEmpty) return const CalendarPreferences();
    try {
      final preferences = CalendarPreferences.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
      return preferences.defaultView == 'agenda'
          ? preferences.copyWith(defaultView: 'week')
          : preferences;
    } on Object {
      return const CalendarPreferences();
    }
  }

  Future<CalendarEvent> create(CalendarEvent event) async {
    final saved =
        event.copyWith(syncStatus: 'pending', version: event.version + 1);
    await _saveEvents([...await loadEvents(), saved]);
    await _queue(saved, 'create');
    return saved;
  }

  Future<CalendarEvent> update(CalendarEvent event) async {
    final saved =
        event.copyWith(syncStatus: 'pending', version: event.version + 1);
    await _saveEvents((await loadEvents())
        .map((item) => item.id == saved.id ? saved : item)
        .toList());
    await _queue(saved, 'update');
    return saved;
  }

  Future<void> remove(CalendarEvent event) async {
    final deleted = event.copyWith(
        status: 'deleted', syncStatus: 'pending', version: event.version + 1);
    await _saveEvents((await loadEvents())
        .map((item) => item.id == event.id ? deleted : item)
        .toList());
    await _queue(deleted, 'delete');
  }

  Future<void> savePreferences(CalendarPreferences preferences) async =>
      _preferences.setString(_preferencesKey, jsonEncode(preferences.toJson()));

  Future<void> _saveEvents(List<CalendarEvent> events) async =>
      _preferences.setString(_eventsKey,
          jsonEncode(events.map((event) => event.toJson()).toList()));

  Future<void> _queue(CalendarEvent event, String operation) async {
    final encoded = _preferences.getString(_queueKey);
    final queue = encoded == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(encoded) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();
    queue.add({
      'id': '${event.id}:$operation:${event.version}',
      'eventId': event.id,
      'operation': operation,
      'version': event.version,
      'createdAt': DateTime.now().toIso8601String(),
      'payload': event.toJson()
    });
    await _preferences.setString(_queueKey, jsonEncode(queue));
  }
}
