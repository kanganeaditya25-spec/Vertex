import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/tasks/task_models.dart';

class TaskRepository {
  TaskRepository(this._preferences);

  final SharedPreferences _preferences;
  static const _tasksKey = 'module3_tasks_v1';
  static const _queueKey = 'module3_task_sync_queue_v1';

  Future<List<TaskModel>> loadTasks() async {
    final encoded = _preferences.getString(_tasksKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TaskModel.fromJson)
          .where((task) => !task.isDeleted)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> loadQueue() async {
    final encoded = _preferences.getString(_queueKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<TaskModel> create(TaskModel task) async {
    final tasks = await loadTasks();
    final next =
        task.copyWith(syncStatus: 'pending', version: task.version + 1);
    await _saveTasks([...tasks, next]);
    await _queue(next, 'create');
    return next;
  }

  Future<TaskModel> update(TaskModel task) async {
    final tasks = await loadTasks();
    final next =
        task.copyWith(syncStatus: 'pending', version: task.version + 1);
    final updated =
        tasks.map((item) => item.id == task.id ? next : item).toList();
    await _saveTasks(updated);
    await _queue(next, 'update');
    return next;
  }

  Future<void> remove(TaskModel task) async {
    final next = task.copyWith(
        status: 'deleted',
        deletedAt: DateTime.now(),
        syncStatus: 'pending',
        version: task.version + 1);
    final tasks = await loadTasks();
    await _saveTasks(
        tasks.map((item) => item.id == task.id ? next : item).toList());
    await _queue(next, 'delete');
  }

  Future<void> replaceAll(List<TaskModel> tasks) => _saveTasks(tasks);

  Future<void> clearQueue() => _preferences.remove(_queueKey);

  Future<void> _saveTasks(List<TaskModel> tasks) async {
    await _preferences.setString(
        _tasksKey, jsonEncode(tasks.map((task) => task.toJson()).toList()));
  }

  Future<void> _queue(TaskModel task, String operation) async {
    final queue = await loadQueue();
    queue.add({
      'id': '${task.id}:$operation:${task.version}',
      'taskId': task.id,
      'operation': operation,
      'version': task.version,
      'createdAt': DateTime.now().toIso8601String(),
      'payload': task.toJson(),
    });
    await _preferences.setString(_queueKey, jsonEncode(queue));
  }
}
