import 'package:flutter/material.dart';

class AnalyticsMetricPoint {
  const AnalyticsMetricPoint(
      {required this.label, required this.value, this.secondaryValue = 0});
  final String label;
  final double value;
  final double secondaryValue;
}

class AnalyticsBreakdownItem {
  const AnalyticsBreakdownItem(
      {required this.label,
      required this.value,
      required this.percentage,
      required this.color});
  final String label;
  final double value;
  final double percentage;
  final Color color;
}

class AnalyticsInsight {
  const AnalyticsInsight(
      {required this.kind,
      required this.title,
      required this.body,
      this.confidence = 0.8});
  final String kind;
  final String title;
  final String body;
  final double confidence;
}

class AnalyticsDashboardModel {
  const AnalyticsDashboardModel(
      {required this.period,
      required this.productivityScore,
      required this.focusScore,
      required this.completionRate,
      required this.goalProgress,
      required this.activeProjects,
      required this.totalTasks,
      required this.completedTasks,
      required this.overdueTasks,
      required this.deepWorkMinutes,
      required this.meetingMinutes,
      required this.learningMinutes,
      required this.notesCreated,
      required this.knowledgeGrowth,
      required this.focusSessions,
      required this.averageSessionMinutes,
      required this.weeklySummary,
      required this.monthlySummary,
      required this.scoreExplanation,
      required this.recommendations,
      required this.dailySeries,
      required this.taskBreakdown,
      required this.categoryBreakdown,
      required this.focusBreakdown});
  final String period;
  final double productivityScore;
  final double focusScore;
  final double completionRate;
  final double goalProgress;
  final int activeProjects;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int deepWorkMinutes;
  final int meetingMinutes;
  final int learningMinutes;
  final int notesCreated;
  final double knowledgeGrowth;
  final int focusSessions;
  final double averageSessionMinutes;
  final String weeklySummary;
  final String monthlySummary;
  final String scoreExplanation;
  final List<String> recommendations;
  final List<AnalyticsMetricPoint> dailySeries;
  final List<AnalyticsBreakdownItem> taskBreakdown;
  final List<AnalyticsBreakdownItem> categoryBreakdown;
  final List<AnalyticsBreakdownItem> focusBreakdown;

  factory AnalyticsDashboardModel.fromJson(Map<String, dynamic> json) =>
      AnalyticsDashboardModel(
          period: '${json['period'] ?? 'weekly'}',
          productivityScore:
              _number(json['productivity_score'] ?? json['productivityScore']),
          focusScore: _number(json['focus_score'] ?? json['focusScore']),
          completionRate:
              _number(json['completion_rate'] ?? json['completionRate']),
          goalProgress: _number(json['goal_progress'] ?? json['goalProgress']),
          activeProjects:
              _integer(json['active_projects'] ?? json['activeProjects']),
          totalTasks: _integer(json['total_tasks'] ?? json['totalTasks']),
          completedTasks:
              _integer(json['completed_tasks'] ?? json['completedTasks']),
          overdueTasks: _integer(json['overdue_tasks'] ?? json['overdueTasks']),
          deepWorkMinutes:
              _integer(json['deep_work_minutes'] ?? json['deepWorkMinutes']),
          meetingMinutes:
              _integer(json['meeting_minutes'] ?? json['meetingMinutes']),
          learningMinutes:
              _integer(json['learning_minutes'] ?? json['learningMinutes']),
          notesCreated: _integer(json['notes_created'] ?? json['notesCreated']),
          knowledgeGrowth:
              _number(json['knowledge_growth'] ?? json['knowledgeGrowth']),
          focusSessions:
              _integer(json['focus_sessions'] ?? json['focusSessions']),
          averageSessionMinutes: _number(
              json['average_session_minutes'] ?? json['averageSessionMinutes']),
          weeklySummary:
              '${json['weekly_summary'] ?? json['weeklySummary'] ?? ''}',
          monthlySummary:
              '${json['monthly_summary'] ?? json['monthlySummary'] ?? ''}',
          scoreExplanation:
              '${json['score_explanation'] ?? json['scoreExplanation'] ?? ''}',
          recommendations:
              (json['recommendations'] as List<dynamic>? ?? const [])
                  .map((value) => '$value')
                  .toList(),
          dailySeries: _points(json['daily_series'] ?? json['dailySeries']),
          taskBreakdown:
              _breakdown(json['task_breakdown'] ?? json['taskBreakdown']),
          categoryBreakdown: _breakdown(
              json['category_breakdown'] ?? json['categoryBreakdown']),
          focusBreakdown:
              _breakdown(json['focus_breakdown'] ?? json['focusBreakdown']));
}

List<AnalyticsMetricPoint> _points(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => AnalyticsMetricPoint(
            label: '${item['label'] ?? ''}',
            value: _number(item['value']),
            secondaryValue:
                _number(item['secondary_value'] ?? item['secondaryValue'])))
        .toList();
List<AnalyticsBreakdownItem> _breakdown(dynamic value) {
  const colors = [
    Color(0xFF4F46E5),
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFFBE123C),
    Color(0xFF0369A1),
    Color(0xFF6D28D9)
  ];
  final items = (value as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
  return [
    for (var index = 0; index < items.length; index++)
      AnalyticsBreakdownItem(
          label: '${items[index]['label'] ?? ''}',
          value: _number(items[index]['value']),
          percentage: _number(items[index]['percentage']),
          color: colors[index % colors.length])
  ];
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
