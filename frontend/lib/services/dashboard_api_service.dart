import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../models/dashboard_models.dart';

class DashboardApiService {
  DashboardApiService(
    this._preferences, {
    Dio? client,
    String? baseUrl,
  })  : _client = client ?? Dio(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final SharedPreferences _preferences;
  final Dio _client;
  final String _baseUrl;

  Future<void> saveAuthToken(String token) async {
    await _preferences.setString(AppConfig.authTokenKey, token);
  }

  Future<void> clearAuthToken() async {
    await _preferences.remove(AppConfig.authTokenKey);
  }

  Future<DashboardSnapshot?> trySync(DashboardSnapshot local) async {
    final token = _preferences.getString(AppConfig.authTokenKey);
    if (token == null || token.isEmpty) return null;

    final options = Options(
      headers: {'Authorization': 'Bearer $token'},
      sendTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    );

    try {
      final responses = await Future.wait([
        _client.get<List<dynamic>>('$_baseUrl/tasks', options: options),
        _client.get<List<dynamic>>('$_baseUrl/goals', options: options),
      ]);
      final tasks = responses[0]
              .data
              ?.whereType<Map<String, dynamic>>()
              .map(_taskFromApi)
              .toList() ??
          const <TaskSummary>[];
      final goals = responses[1]
              .data
              ?.whereType<Map<String, dynamic>>()
              .map(_goalFromApi)
              .toList() ??
          const <GoalSummary>[];

      return DashboardSnapshot(
        userName: local.userName,
        tasks: tasks,
        goals: goals,
        events: local.events,
        projects: local.projects,
        habits: local.habits,
        notes: local.notes,
        focus: local.focus,
        lastUpdated: DateTime.now(),
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  TaskSummary _taskFromApi(Map<String, dynamic> json) {
    final goal = json['goal'];
    final goalMap = goal is Map<String, dynamic> ? goal : null;
    return TaskSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'todo',
      priority: json['priority'] as String? ?? 'medium',
      dueAt: _parseDate(json['due_date'] ?? json['dueAt']),
      estimatedMinutes:
          (json['estimated_minutes'] ?? json['estimatedMinutes'] as num?) is num
              ? ((json['estimated_minutes'] ?? json['estimatedMinutes']) as num)
                  .toInt()
              : 0,
      goalTitle: goalMap?['title'] as String?,
    );
  }

  GoalSummary _goalFromApi(Map<String, dynamic> json) => GoalSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        targetDate: _parseDate(json['target_date'] ?? json['targetDate']),
        linkedTaskCount: (json['linked_task_count'] ??
                json['linkedTaskCount'] as num?) is num
            ? ((json['linked_task_count'] ?? json['linkedTaskCount']) as num)
                .toInt()
            : 0,
        completedTaskCount: (json['completed_task_count'] ??
                json['completedTaskCount'] as num?) is num
            ? ((json['completed_task_count'] ?? json['completedTaskCount'])
                    as num)
                .toInt()
            : 0,
      );

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
