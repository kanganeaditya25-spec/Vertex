import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_dashboard/features/calendar/calendar_models.dart';

void main() {
  test('calendar event round-trips and preserves duration metadata', () {
    final start = DateTime.utc(2026, 8, 21, 9);
    final event = CalendarEvent(
        id: 'event-1',
        title: 'Deep work',
        startAt: start,
        endAt: start.add(const Duration(minutes: 90)),
        eventType: 'deep_work',
        priority: 'high',
        energyLevel: 'high',
        aiScheduled: true);
    final decoded = CalendarEvent.fromJson(event.toJson());

    expect(decoded.title, 'Deep work');
    expect(decoded.duration, const Duration(minutes: 90));
    expect(decoded.eventType, 'deep_work');
    expect(decoded.aiScheduled, isTrue);
  });

  test('future calendar events retain their selected day and time', () {
    final start = DateTime.utc(2026, 8, 24, 14, 15);
    final event = CalendarEvent(
      id: 'future-event',
      title: 'Planning session',
      startAt: start,
      endAt: start.add(const Duration(minutes: 50)),
    );

    final decoded = CalendarEvent.fromJson(event.toJson());

    expect(decoded.startAt, start);
    expect(decoded.startAt.day, 24);
    expect(decoded.startAt.hour, 14);
    expect(
        decoded.endAt.difference(decoded.startAt), const Duration(minutes: 50));
  });

  test('calendar preferences retain accessibility and view settings', () {
    const preferences = CalendarPreferences(
        defaultView: 'day',
        reducedMotion: true,
        highContrast: true,
        density: 'compact');
    final decoded = CalendarPreferences.fromJson(preferences.toJson());

    expect(decoded.defaultView, 'day');
    expect(decoded.reducedMotion, isTrue);
    expect(decoded.highContrast, isTrue);
    expect(decoded.density, 'compact');
  });
}
