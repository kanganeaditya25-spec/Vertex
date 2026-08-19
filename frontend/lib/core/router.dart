import 'package:go_router/go_router.dart';

import '../features/analytics/analytics_page.dart';
import '../features/assets/assets_page.dart';
import '../features/automation/automation_page.dart';
import '../features/assistant/assistant_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/notes/notes_page.dart';
import '../features/organization/organization_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/tasks/task_home_page.dart';
import '../features/settings/settings_page.dart';
import '../features/reminders/reminders_page.dart';
import '../features/knowledge_graph/knowledge_graph_page.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
    GoRoute(
      path: '/tasks',
      builder: (context, state) =>
          TaskHomePage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) =>
          CalendarPage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/notes',
      builder: (context, state) =>
          NotesPage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/assistant',
      builder: (context, state) =>
          AssistantPage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/organization',
      builder: (context, state) => const OrganizationPage(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) =>
          AnalyticsPage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/automation',
      builder: (context, state) => const AutomationPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/assets',
      builder: (context, state) =>
          AssetsPage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/reminders',
      builder: (context, state) =>
          RemindersPage(projectId: state.uri.queryParameters['project']),
    ),
    GoRoute(
      path: '/knowledge-graph',
      builder: (context, state) => KnowledgeGraphPage(
        workspaceId: state.uri.queryParameters['workspace'],
      ),
    ),
  ],
);
