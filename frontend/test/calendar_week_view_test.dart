import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity_dashboard/features/calendar/calendar_models.dart';
import 'package:productivity_dashboard/repositories/calendar_repository.dart';

void main() {
  test('new calendar preferences default to week view', () {
    const preferences = CalendarPreferences();
    expect(preferences.defaultView, 'week');
  });

  test('stored agenda preference migrates to week view', () async {
    SharedPreferences.setMockInitialValues({
      'module4_calendar_preferences_v1': jsonEncode(
          const CalendarPreferences(defaultView: 'agenda').toJson()),
    });
    final preferences = await SharedPreferences.getInstance();
    final loaded = await CalendarRepository(preferences).loadPreferences();
    expect(loaded.defaultView, 'week');
  });
}
