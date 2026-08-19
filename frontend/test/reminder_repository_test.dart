import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/features/reminders/reminder_models.dart';
import 'package:productivity_dashboard/repositories/reminder_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists reminders and records snooze history offline', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = ReminderRepository(preferences);
    final reminder = await repository.create(
        title: 'Review notes',
        nextTriggerAt: DateTime.now().add(const Duration(minutes: 5)),
        linkedModule: 'notes');

    await repository.snooze(reminder.id, 15);
    final loaded = await repository.get(reminder.id);
    final history = await repository.loadHistory();

    expect(loaded, isNotNull);
    expect(loaded!.snoozedCount, 1);
    expect(history.any((item) => item.action == 'snooze'), isTrue);
  });

  test('completing a recurring reminder schedules its next occurrence',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = ReminderRepository(preferences);
    final reminder = await repository.create(
        title: 'Daily review',
        nextTriggerAt: DateTime.now().subtract(const Duration(minutes: 1)),
        repeatRule: const {'kind': 'daily'});

    await repository.complete(reminder.id);
    final loaded = await repository.get(reminder.id);

    expect(loaded!.status, 'scheduled');
    expect(loaded.nextTriggerAt, isNotNull);
    expect(loaded.nextTriggerAt!.isAfter(DateTime.now()), isTrue);
  });

  test('quiet hours suppress normal due reminders but allow critical alerts',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = ReminderRepository(preferences);
    await repository.savePreferences(const ReminderPreferencesModel(
        quietHoursEnabled: true, quietStartMinutes: 0, quietEndMinutes: 1439));
    final normal = await repository.create(
        title: 'Normal due',
        nextTriggerAt: DateTime.now().subtract(const Duration(minutes: 1)));
    final critical = await repository.create(
        title: 'Critical due',
        nextTriggerAt: DateTime.now().subtract(const Duration(minutes: 1)),
        priority: 1);
    await repository.save((await repository.get(critical.id))!
        .copyWith(notificationType: 'critical'));

    final due = await repository.due();

    expect(due.any((item) => item.id == normal.id), isFalse);
    expect(due.any((item) => item.id == critical.id), isTrue);
  });
}
