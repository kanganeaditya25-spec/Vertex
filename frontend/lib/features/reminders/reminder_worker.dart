import 'dart:async';

import 'reminder_models.dart';
import '../../repositories/reminder_repository.dart';

class LocalNotificationService {
  final List<ReminderModel> _delivered = [];

  List<ReminderModel> get delivered => List.unmodifiable(_delivered);

  void deliver(ReminderModel reminder) {
    if (_delivered.any((item) =>
        item.id == reminder.id &&
        item.nextTriggerAt == reminder.nextTriggerAt)) {
      return;
    }
    _delivered.insert(0, reminder);
    if (_delivered.length > 100) _delivered.removeLast();
  }

  void dismiss(String id) => _delivered.removeWhere((item) => item.id == id);
  void clear() => _delivered.clear();
}

class ReminderWorker {
  ReminderWorker(this._repository, this._notifications);
  final ReminderRepository _repository;
  final LocalNotificationService _notifications;
  Timer? _timer;

  void start(Future<void> Function(List<ReminderModel>)? onDue) {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => tick(onDue));
    tick(onDue);
  }

  Future<List<ReminderModel>> tick(
      Future<void> Function(List<ReminderModel>)? onDue) async {
    final due = await _repository.due();
    for (final reminder in due) {
      _notifications.deliver(reminder);
    }
    if (onDue != null && due.isNotEmpty) await onDue(due);
    return due;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
