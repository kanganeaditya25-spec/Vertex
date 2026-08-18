import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_dashboard/features/analytics/analytics_models.dart';
import 'package:productivity_dashboard/repositories/analytics_repository.dart';

void main() {
  test('offline focus sessions contribute to the analytics dashboard', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = AnalyticsRepository(preferences);

    await repository.saveFocusSession(minutes: 45, sessionType: 'deep_work');
    final dashboard = await repository.loadDashboard(period: 'weekly');

    expect(dashboard.deepWorkMinutes, 45);
    expect(dashboard.focusSessions, 1);
    expect(dashboard.recommendations, isNotEmpty);
    expect(dashboard.scoreExplanation, contains('30% task completion'));
  });

  test('analytics dashboard model parses backend snake case contracts', () {
    final dashboard = AnalyticsDashboardModel.fromJson({
      'period': 'daily',
      'productivity_score': 72,
      'focus_score': 80,
      'completion_rate': 60,
      'goal_progress': 55,
      'active_projects': 2,
      'total_tasks': 5,
      'completed_tasks': 3,
      'overdue_tasks': 1,
      'deep_work_minutes': 90,
      'meeting_minutes': 30,
      'learning_minutes': 20,
      'notes_created': 4,
      'knowledge_growth': 40,
      'focus_sessions': 2,
      'average_session_minutes': 45,
      'weekly_summary': 'summary',
      'monthly_summary': 'month',
      'score_explanation': 'explanation',
      'recommendations': ['Protect a focus block'],
      'daily_series': [{'label': 'Today', 'value': 3, 'secondary_value': 90}],
      'task_breakdown': [{'label': 'completed', 'value': 3, 'percentage': 60}],
      'category_breakdown': [],
      'focus_breakdown': [],
    });

    expect(dashboard.productivityScore, 72);
    expect(dashboard.dailySeries.single.secondaryValue, 90);
    expect(dashboard.taskBreakdown.single.percentage, 60);
  });
}
