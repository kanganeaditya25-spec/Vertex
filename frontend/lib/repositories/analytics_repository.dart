import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/analytics/analytics_models.dart';
import '../features/calendar/calendar_models.dart';
import '../features/tasks/task_models.dart';
import 'calendar_repository.dart';
import 'notes_repository.dart';
import 'organization_repository.dart';
import 'task_repository.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._preferences);
  final SharedPreferences _preferences;
  static const _focusSessionsKey = 'module8_focus_sessions_v1';

  Future<AnalyticsDashboardModel> loadDashboard(
      {String period = 'weekly'}) async {
    final now = DateTime.now();
    final days = period == 'daily'
        ? 1
        : period == 'monthly'
            ? 30
            : period == 'yearly'
                ? 365
                : 7;
    final start = now.subtract(Duration(days: days));
    final tasks = await TaskRepository(_preferences).loadTasks();
    final allTasks = tasks.where((task) => task.status != 'deleted').toList();
    final events = await CalendarRepository(_preferences).loadEvents();
    final notes = await NotesRepository(_preferences).loadNotes();
    final projects = await OrganizationRepository(_preferences).loadProjects();
    final goals = await OrganizationRepository(_preferences).loadGoals();
    final sessions = await _loadSessions();
    final rangeTasks =
        allTasks.where((task) => _within(task.createdAt, start, now)).toList();
    final completedTasks =
        rangeTasks.where((task) => task.status == 'completed').length;
    final overdue = allTasks
        .where((task) =>
            task.deadline != null &&
            task.deadline!.isBefore(now) &&
            !{'completed', 'cancelled', 'archived', 'deleted'}
                .contains(task.status))
        .length;
    final rangeEvents = events
        .where((event) =>
            event.endAt.isAfter(start) &&
            event.startAt.isBefore(now) &&
            !event.isCancelled &&
            !event.isArchived)
        .toList();
    final rangeNotes = notes
        .where((note) =>
            _within(note.createdAt ?? now, start, now) &&
            !note.deleted &&
            !note.archived)
        .toList();
    final rangeSessions = sessions
        .where((session) => _within(session.startedAt, start, now))
        .toList();
    final deepWork = rangeSessions
            .where((session) => {'deep_work', 'focus', 'pomodoro'}
                .contains(session.sessionType))
            .fold<int>(0, (sum, item) => sum + item.minutes) +
        rangeEvents
            .where((event) =>
                {'deep_work', 'focus_block'}.contains(event.eventType))
            .fold<int>(0, (sum, item) => sum + item.duration.inMinutes);
    final meeting = rangeEvents
        .where((event) => event.eventType == 'meeting')
        .fold<int>(0, (sum, item) => sum + item.duration.inMinutes);
    final learning = rangeEvents
        .where((event) => event.eventType == 'study')
        .fold<int>(0, (sum, item) => sum + item.duration.inMinutes);
    final completionRate =
        rangeTasks.isEmpty ? 0.0 : completedTasks / rangeTasks.length * 100;
    final goalProgress = goals.isEmpty
        ? 0.0
        : goals.map((goal) => goal.progress).reduce((a, b) => a + b) /
            goals.length;
    final focusScore = (deepWork / (days * 60) * 100).clamp(0, 100).toDouble();
    final consistency = _consistency(rangeTasks, start, now);
    final score = (completionRate * .30 +
            focusScore * .20 +
            goalProgress * .20 +
            consistency * .15 +
            (100 - (meeting / (days * 480) * 100).clamp(0, 100)) * .15)
        .clamp(0, 100)
        .toDouble();
    final recommendations = <String>[];
    if (overdue > 0) {
      recommendations.add(
          'Review $overdue overdue task(s) and choose one recovery action before adding new work.');
    }
    if (completionRate < 50) {
      recommendations.add(
          'Reduce active work in progress and define a smaller daily finish line.');
    }
    if (focusScore < 35) {
      recommendations.add(
          'Protect one uninterrupted focus block; the current range has limited deep-work time.');
    }
    if (goalProgress < 50) {
      recommendations.add(
          'Link the next task to a goal so daily execution contributes to a visible outcome.');
    }
    if (recommendations.isEmpty) {
      recommendations.add(
          'Keep the current rhythm and review the next milestone before the next planning cycle.');
    }
    return AnalyticsDashboardModel(
        period: period,
        productivityScore: score,
        focusScore: focusScore,
        completionRate: completionRate,
        goalProgress: goalProgress,
        activeProjects: projects
            .where((project) => project.status == 'active' && !project.archived)
            .length,
        totalTasks: rangeTasks.length,
        completedTasks: completedTasks,
        overdueTasks: overdue,
        deepWorkMinutes: deepWork,
        meetingMinutes: meeting,
        learningMinutes: learning,
        notesCreated: rangeNotes.length,
        knowledgeGrowth: rangeNotes.isEmpty
            ? 0
            : rangeNotes
                    .map((note) => note.knowledgeScore)
                    .reduce((a, b) => a + b) /
                rangeNotes.length,
        focusSessions: rangeSessions.length,
        averageSessionMinutes:
            rangeSessions.isEmpty
                ? 0
                : rangeSessions
                        .map((session) => session.minutes)
                        .reduce((a, b) => a + b) /
                    rangeSessions.length,
        weeklySummary:
            '$completedTasks of ${rangeTasks.length} tasks completed, $deepWork focus minutes, and $overdue overdue tasks in this range.',
        monthlySummary:
            'The workspace contains ${projects.where((project) => !project.archived).length} active projects, ${goals.where((goal) => !goal.archived).length} tracked goals, and ${rangeNotes.length} notes created in the selected range.',
        scoreExplanation:
            'Productivity score = 30% task completion + 20% focus time + 20% goal progress + 15% consistency + 15% time management. All values are calculated from local records.',
        recommendations: recommendations.take(5).toList(),
        dailySeries: _series(rangeTasks, rangeSessions, start, days),
        taskBreakdown: _taskBreakdown(rangeTasks, overdue),
        categoryBreakdown: _categoryBreakdown(rangeTasks),
        focusBreakdown: _focusBreakdown(rangeEvents));
  }

  Future<void> saveFocusSession(
      {required int minutes,
      String sessionType = 'deep_work',
      int interruptions = 0}) async {
    final sessions = await _loadSessions();
    sessions.add(_FocusSession(
        startedAt: DateTime.now().subtract(Duration(minutes: minutes)),
        minutes: minutes,
        sessionType: sessionType,
        interruptions: interruptions));
    await _preferences.setString(_focusSessionsKey,
        jsonEncode(sessions.map((item) => item.toJson()).toList()));
  }

  Future<List<_FocusSession>> _loadSessions() async {
    final encoded = _preferences.getString(_focusSessionsKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(_FocusSession.fromJson)
          .toList();
    } on Object {
      return [];
    }
  }

  bool _within(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && !value.isAfter(end);
  double _consistency(List<TaskModel> tasks, DateTime start, DateTime end) {
    final totalDays = end.difference(start).inDays + 1;
    final active = tasks
        .map((task) => DateTime(
            task.createdAt.year, task.createdAt.month, task.createdAt.day))
        .toSet()
        .length;
    return (active / totalDays * 100).clamp(0, 100).toDouble();
  }

  List<AnalyticsMetricPoint> _series(List<TaskModel> tasks,
          List<_FocusSession> sessions, DateTime start, int days) =>
      [
        for (var offset = 0; offset < days; offset++)
          () {
            final date = DateTime(start.year, start.month, start.day + offset);
            final completed = tasks
                .where((task) =>
                    task.status == 'completed' &&
                    _sameDay(task.updatedAt, date))
                .length;
            final focus = sessions
                .where((session) => _sameDay(session.startedAt, date))
                .fold<int>(0, (sum, item) => sum + item.minutes);
            return AnalyticsMetricPoint(
                label: '${date.month}/${date.day}',
                value: completed.toDouble(),
                secondaryValue: focus.toDouble());
          }()
      ];
  List<AnalyticsBreakdownItem> _taskBreakdown(
      List<TaskModel> tasks, int overdue) {
    final counts = <String, int>{
      'completed': tasks.where((task) => task.status == 'completed').length,
      'open': tasks.where((task) => task.status != 'completed').length,
      'overdue': overdue
    };
    return _breakdown(counts);
  }

  List<AnalyticsBreakdownItem> _categoryBreakdown(List<TaskModel> tasks) {
    final counts = <String, int>{};
    for (final task in tasks) {
      counts[task.category] = (counts[task.category] ?? 0) + 1;
    }
    return _breakdown(counts);
  }

  List<AnalyticsBreakdownItem> _focusBreakdown(List<CalendarEvent> events) {
    final counts = <String, int>{};
    for (final event in events.where((event) => {
          'deep_work',
          'focus_block',
          'meeting',
          'study',
          'break'
        }.contains(event.eventType))) {
      counts[event.eventType] =
          (counts[event.eventType] ?? 0) + event.duration.inMinutes;
    }
    return _breakdown(counts);
  }

  List<AnalyticsBreakdownItem> _breakdown(Map<String, int> counts) {
    const colors = [
      Color(0xFF4F46E5),
      Color(0xFF0F766E),
      Color(0xFFB45309),
      Color(0xFFBE123C),
      Color(0xFF0369A1),
      Color(0xFF6D28D9)
    ];
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (var index = 0; index < entries.length; index++)
        AnalyticsBreakdownItem(
            label: entries[index].key,
            value: entries[index].value.toDouble(),
            percentage: total == 0 ? 0 : entries[index].value / total * 100,
            color: colors[index % colors.length])
    ];
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _FocusSession {
  const _FocusSession(
      {required this.startedAt,
      required this.minutes,
      required this.sessionType,
      this.interruptions = 0});
  final DateTime startedAt;
  final int minutes;
  final String sessionType;
  final int interruptions;
  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'minutes': minutes,
        'sessionType': sessionType,
        'interruptions': interruptions
      };
  factory _FocusSession.fromJson(Map<String, dynamic> json) => _FocusSession(
      startedAt: DateTime.tryParse('${json['startedAt']}') ?? DateTime.now(),
      minutes: json['minutes'] is num
          ? (json['minutes'] as num).toInt()
          : int.tryParse('${json['minutes']}') ?? 0,
      sessionType: '${json['sessionType'] ?? 'deep_work'}',
      interruptions: json['interruptions'] is num
          ? (json['interruptions'] as num).toInt()
          : 0);
}
