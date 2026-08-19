import 'package:flutter_test/flutter_test.dart';

import 'package:productivity_dashboard/features/calendar/calendar_models.dart';
import 'package:productivity_dashboard/features/calendar/calendar_providers.dart';
import 'package:productivity_dashboard/features/organization/organization_models.dart';
import 'package:productivity_dashboard/features/organization/organization_providers.dart';
import 'package:productivity_dashboard/features/reminders/reminder_models.dart';
import 'package:productivity_dashboard/features/reminders/reminder_providers.dart';
import 'package:productivity_dashboard/features/tasks/task_models.dart';
import 'package:productivity_dashboard/features/tasks/task_providers.dart';

void main() {
  test('clearing the selected project prevents stale cross-workspace context',
      () {
    const workspaceOne = WorkspaceModel(id: 'workspace-one', name: 'One');
    const workspaceTwo = WorkspaceModel(id: 'workspace-two', name: 'Two');
    const project = ProjectModel(
        id: 'project-one', workspaceId: 'workspace-one', name: 'Project One');
    const state = OrganizationState(
      workspaces: [workspaceOne, workspaceTwo],
      projects: [project],
      goals: [],
      milestones: [],
      templates: [],
      selectedWorkspaceId: 'workspace-one',
      selectedProjectId: 'project-one',
    );

    final switched = state.copyWith(
        selectedWorkspaceId: workspaceTwo.id, clearSelectedProject: true);

    expect(state.selectedProject?.id, project.id);
    expect(switched.selectedProject, isNull);
    expect(switched.workspaceProjects, isEmpty);
  });

  test('TaskState filters tasks by stable project ID', () {
    final now = DateTime.now();
    final state = TaskState(tasks: [
      TaskModel(
          id: 'task-one',
          title: 'One',
          project: 'project-one',
          createdAt: now,
          updatedAt: now),
      TaskModel(
          id: 'task-two',
          title: 'Two',
          project: 'project-two',
          createdAt: now,
          updatedAt: now),
    ]);

    expect(state.visibleTasksFor('project-one').map((task) => task.id),
        ['task-one']);
  });

  test('CalendarState filters events by stable project ID', () {
    final now = DateTime.now();
    final state = CalendarState(
      events: [
        CalendarEvent(
            id: 'event-one',
            title: 'One',
            startAt: now,
            endAt: now.add(const Duration(hours: 1)),
            projectId: 'project-one'),
        CalendarEvent(
            id: 'event-two',
            title: 'Two',
            startAt: now,
            endAt: now.add(const Duration(hours: 1)),
            projectId: 'project-two'),
      ],
      selectedDate: DateTime(now.year, now.month, now.day),
      preferences: const CalendarPreferences(),
    );

    expect(state.visibleEventsFor('project-one').map((event) => event.id),
        ['event-one']);
  });

  test('ReminderState filters reminders by stable project ID', () {
    final state = ReminderState(
      reminders: [
        ReminderModel(
            id: 'reminder-one', title: 'One', projectId: 'project-one'),
        ReminderModel(
            id: 'reminder-two', title: 'Two', projectId: 'project-two'),
      ],
      history: const [],
      preferences: const ReminderPreferencesModel(),
      stats: const ReminderStatsModel(),
    );

    expect(state.visibleRemindersFor('project-one').map((item) => item.id),
        ['reminder-one']);
  });
}
