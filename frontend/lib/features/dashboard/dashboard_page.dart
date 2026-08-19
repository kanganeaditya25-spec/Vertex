import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dashboard_models.dart';
import '../../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardControllerProvider);

    return dashboard.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Productivity')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Dashboard could not load',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(dashboardControllerProvider.notifier).refresh(),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (state) => _DashboardView(state: state),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;
    final controller = ref.read(dashboardControllerProvider.notifier);
    final snapshot = state.snapshot;
    final todayTasks = snapshot.tasks;
    final completedTasks = todayTasks.where((task) => task.isCompleted).length;
    final pendingTasks = todayTasks.length - completedTasks;
    final activeGoals =
        snapshot.goals.where((goal) => goal.progress < 100).toList();
    final topTasks = [...todayTasks]..sort(_comparePriority);
    final visible = state.preferences.visibleWidgets.toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFlow AI'),
        actions: [
          IconButton(
            tooltip: 'Open Analytics & Insights',
            onPressed: () => context.push('/analytics'),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: 'Open Asset Library',
            onPressed: () => context.push('/assets'),
            icon: const Icon(Icons.folder_copy_outlined),
          ),
          IconButton(
            tooltip: 'Open Reminder Center',
            onPressed: () => context.push('/reminders'),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'Open Knowledge Explorer',
            onPressed: () => context.push('/knowledge-graph'),
            icon: const Icon(Icons.hub_outlined),
          ),
          IconButton(
            tooltip: 'Open Settings & Personalization',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Open Automation Engine',
            onPressed: () => context.push('/automation'),
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            tooltip: 'Open Workspaces & Projects',
            onPressed: () => context.push('/organization'),
            icon: const Icon(Icons.account_tree_rounded),
          ),
          IconButton(
            tooltip: 'Open AI Executive Assistant',
            onPressed: () => context.push('/assistant'),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          IconButton(
            tooltip: 'Open Second Brain Notes',
            onPressed: () => context.push('/notes'),
            icon: const Icon(Icons.menu_book_rounded),
          ),
          IconButton(
            tooltip: 'Open Calendar & Time Intelligence',
            onPressed: () => context.push('/calendar'),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Open Smart Tasks',
            onPressed: () => context.push('/tasks'),
            icon: const Icon(Icons.checklist_rounded),
          ),
          IconButton(
            tooltip: 'Search your workspace',
            onPressed: () => _showSearch(context),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _showNotifications(context),
            icon: const Badge(
              label: Text('0'),
              child: Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            tooltip: 'Customize dashboard',
            onPressed: () => _showCustomization(context, state, controller),
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _GreetingHeader(
              userName: snapshot.userName,
              activeGoal: activeGoals.isEmpty ? null : activeGoals.first,
            ),
            const SizedBox(height: 20),
            _ResponsiveGrid(
              columns: isDesktop ? 2 : 1,
              children: [
                if (visible.contains('today_overview'))
                  _TodayOverviewCard(
                    tasksRemaining: pendingTasks,
                    completedTasks: completedTasks,
                    meetings: snapshot.events.length,
                    focusSeconds: snapshot.focus.todaySeconds,
                    progress: todayTasks.isEmpty
                        ? 0
                        : completedTasks / todayTasks.length,
                  ),
                if (visible.contains('ai_priority'))
                  _PriorityCard(tasks: topTasks.take(3).toList()),
              ],
            ),
            const SizedBox(height: 16),
            if (visible.contains('focus'))
              _FocusCard(focus: snapshot.focus, controller: controller),
            const SizedBox(height: 16),
            _QuickActions(controller: controller),
            const SizedBox(height: 16),
            _ResponsiveGrid(
              columns: isDesktop ? 2 : 1,
              children: [
                if (visible.contains('calendar'))
                  _CalendarCard(events: snapshot.events),
                if (visible.contains('recent_notes'))
                  _RecentNotesCard(notes: snapshot.notes),
                if (visible.contains('projects'))
                  _ProjectsCard(projects: snapshot.projects),
                if (visible.contains('habits'))
                  _HabitsCard(habits: snapshot.habits),
                if (visible.contains('analytics'))
                  _AnalyticsCard(tasks: todayTasks, focus: snapshot.focus),
                _AiInsightCard(available: state.localAiAvailable),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.userName, required this.activeGoal});

  final String userName;
  final GoalSummary? activeGoal;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final date = MaterialLocalizations.of(context).formatMediumDate(now);

    return Semantics(
      header: true,
      label: '$greeting $userName, $date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $userName',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(date, style: Theme.of(context).textTheme.bodyMedium),
          if (activeGoal != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.track_changes,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Current goal: ${activeGoal!.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.tasksRemaining,
    required this.completedTasks,
    required this.meetings,
    required this.focusSeconds,
    required this.progress,
  });

  final int tasksRemaining;
  final int completedTasks;
  final int meetings;
  final int focusSeconds;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Today overview',
      icon: Icons.today_outlined,
      child: Column(
        children: [
          Row(
            children: [
              _Metric(label: 'Remaining', value: '$tasksRemaining'),
              _Metric(label: 'Completed', value: '$completedTasks'),
              _Metric(label: 'Events', value: '$meetings'),
              _Metric(label: 'Focus', value: _formatDuration(focusSeconds)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Progress updates from your task activity.'),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.tasks});

  final List<TaskSummary> tasks;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'AI priority queue',
      icon: Icons.auto_awesome_outlined,
      trailing: const Chip(label: Text('Local AI')),
      child: tasks.isEmpty
          ? const _EmptyMessage(
              icon: Icons.check_circle_outline,
              message: 'No tasks need prioritization right now.',
            )
          : Column(
              children: tasks
                  .map(
                    (task) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text('${tasks.indexOf(task) + 1}'),
                      ),
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_taskReason(task)),
                      trailing: _PriorityBadge(priority: task.priority),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.focus, required this.controller});

  final FocusSummary focus;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final action = !focus.isRunning
        ? FilledButton.icon(
            onPressed: controller.startFocus,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start focus'),
          )
        : focus.isPaused
            ? FilledButton.icon(
                onPressed: controller.resumeFocus,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              )
            : OutlinedButton.icon(
                onPressed: controller.pauseFocus,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              );

    return _SectionCard(
      title: 'Focus mode',
      icon: Icons.timer_outlined,
      trailing: focus.isRunning ? const Chip(label: Text('Active')) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTimer(focus.elapsedSeconds),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today ${_formatDuration(focus.todaySeconds)} · Longest ${_formatDuration(focus.longestSessionSeconds)}',
                ),
              ],
            ),
          ),
          action,
          if (focus.isRunning) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Stop focus',
              onPressed: controller.stopFocus,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick actions',
      icon: Icons.bolt_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.timer_outlined, size: 18),
            label: const Text('Start focus'),
            onPressed: controller.startFocus,
          ),
          ActionChip(
            avatar: const Icon(Icons.add_task, size: 18),
            label: const Text('New task'),
            onPressed: () => context.push('/tasks'),
          ),
          ActionChip(
            avatar: const Icon(Icons.event_outlined, size: 18),
            label: const Text('Calendar'),
            onPressed: () => context.push('/calendar'),
          ),
          ActionChip(
            avatar: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Notes'),
            onPressed: () => context.push('/notes'),
          ),
          ActionChip(
            avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Assistant'),
            onPressed: () => context.push('/assistant'),
          ),
          ActionChip(
            avatar: const Icon(Icons.account_tree_rounded, size: 18),
            label: const Text('Projects'),
            onPressed: () => context.push('/organization'),
          ),
          ActionChip(
            avatar: const Icon(Icons.insights_rounded, size: 18),
            label: const Text('Analytics'),
            onPressed: () => context.push('/analytics'),
          ),
          ActionChip(
            avatar: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('Automation'),
            onPressed: () => context.push('/automation'),
          ),
          ActionChip(
            avatar: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Settings'),
            onPressed: () => context.push('/settings'),
          ),
          ActionChip(
            avatar: const Icon(Icons.folder_copy_outlined, size: 18),
            label: const Text('Assets'),
            onPressed: () => context.push('/assets'),
          ),
          ActionChip(
            avatar: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Reminders'),
            onPressed: () => context.push('/reminders'),
          ),
          const ActionChip(
            avatar: Icon(Icons.note_add_outlined, size: 18),
            label: Text('New note'),
          ),
          const ActionChip(
            avatar: Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text('AI plan'),
          ),
          const ActionChip(
            avatar: Icon(Icons.mic_none, size: 18),
            label: Text('Voice command'),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Calendar preview',
      icon: Icons.calendar_month_outlined,
      child: events.isEmpty
          ? const _EmptyMessage(
              icon: Icons.event_available_outlined,
              message: 'No events saved for today.',
            )
          : Column(
              children: events
                  .take(4)
                  .map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        TimeOfDay.fromDateTime(event.startsAt).format(context),
                      ),
                      title: Text(event.title),
                      subtitle: Text('${event.durationMinutes} minutes'),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _RecentNotesCard extends StatelessWidget {
  const _RecentNotesCard({required this.notes});

  final List<NoteSummary> notes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent notes',
      icon: Icons.notes_outlined,
      child: notes.isEmpty
          ? const _EmptyMessage(
              icon: Icons.note_add_outlined,
              message: 'Your recent notes will appear here.',
            )
          : Column(
              children: notes
                  .take(4)
                  .map(
                    (note) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(note.pinned ? Icons.push_pin : Icons.notes),
                      title: Text(note.title),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(note.updatedAt),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  const _ProjectsCard({required this.projects});

  final List<ProjectSummary> projects;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Project status',
      icon: Icons.folder_open_outlined,
      child: projects.isEmpty
          ? const _EmptyMessage(
              icon: Icons.folder_outlined,
              message: 'No active projects yet.',
            )
          : Column(
              children: projects
                  .take(4)
                  .map(
                    (project) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(project.name)),
                              if (project.blocked)
                                const Chip(label: Text('Blocked')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: project.progress.clamp(0, 1).toDouble(),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.habits});

  final List<HabitSummary> habits;

  @override
  Widget build(BuildContext context) {
    final completed = habits.where((habit) => habit.completed).length;
    return _SectionCard(
      title: 'Habits',
      icon: Icons.repeat_outlined,
      trailing: Text('$completed/${habits.length}'),
      child: habits.isEmpty
          ? const _EmptyMessage(
              icon: Icons.loop_outlined,
              message: 'Create habits to build a visible streak.',
            )
          : Column(
              children: habits
                  .take(5)
                  .map(
                    (habit) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: habit.completed,
                      onChanged: null,
                      title: Text(habit.name),
                      subtitle: Text('${habit.streak} day streak'),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.tasks, required this.focus});

  final List<TaskSummary> tasks;
  final FocusSummary focus;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isCompleted).length.toDouble();
    final pending =
        (tasks.length - completed).clamp(0, double.infinity).toDouble();
    return _SectionCard(
      title: 'Productivity analytics',
      icon: Icons.insights_outlined,
      child: SizedBox(
        height: 170,
        child: BarChart(
          BarChartData(
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final label = value == 0
                        ? 'Done'
                        : value == 1
                            ? 'Pending'
                            : 'Focus';
                    return SideTitleWidget(meta: meta, child: Text(label));
                  },
                ),
              ),
            ),
            barGroups: [
              _bar(0, completed, context),
              _bar(1, pending, context),
              _bar(
                2,
                (focus.todaySeconds / 3600).clamp(0, 12).toDouble(),
                context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double value, BuildContext context) =>
      BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Theme.of(context).colorScheme.primary,
            width: 26,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'AI insights',
      icon: Icons.auto_awesome_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            available
                ? Icons.check_circle_outline
                : Icons.offline_bolt_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              available
                  ? 'Local Ollama is ready for private summaries and recommendations.'
                  : 'Local AI is available when Ollama is running. Core dashboard data remains local and usable without it.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            )
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map(
            (child) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: child,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = priority == 'high'
        ? Colors.red
        : priority == 'low'
            ? Colors.green
            : Colors.orange;
    return Chip(
      label: Text(priority),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      labelStyle: TextStyle(color: color),
    );
  }
}

int _comparePriority(TaskSummary a, TaskSummary b) {
  const rank = {'high': 0, 'medium': 1, 'low': 2};
  final priority = (rank[a.priority] ?? 1).compareTo(rank[b.priority] ?? 1);
  if (priority != 0) return priority;
  final aDue = a.dueAt ?? DateTime(9999);
  final bDue = b.dueAt ?? DateTime(9999);
  return aDue.compareTo(bDue);
}

String _taskReason(TaskSummary task) {
  if (task.dueAt != null) {
    return 'Due ${task.dueAt!.month}/${task.dueAt!.day} · ${task.estimatedMinutes} min';
  }
  if (task.goalTitle != null) {
    return 'Supports ${task.goalTitle}';
  }
  return 'Priority ${task.priority}';
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _formatTimer(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remaining = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

void _showSearch(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Search workspace'),
      content: const TextField(
        autofocus: true,
        decoration: InputDecoration(hintText: 'Tasks, notes, projects, files'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showNotifications(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: _EmptyMessage(
          icon: Icons.notifications_none,
          message: 'No unread notifications.',
        ),
      ),
    ),
  );
}

void _showCustomization(
  BuildContext context,
  DashboardState state,
  DashboardController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize dashboard',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final widgetId
                in DashboardPreferences.defaults().visibleWidgets)
              SwitchListTile(
                title: Text(_widgetLabel(widgetId)),
                value: state.preferences.visibleWidgets.contains(widgetId),
                onChanged: (_) => controller.toggleWidget(widgetId),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: controller.resetLayout,
                child: const Text('Reset layout'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _widgetLabel(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
