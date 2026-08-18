import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'organization_models.dart';
import 'organization_providers.dart';

class OrganizationPage extends ConsumerWidget {
  const OrganizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(organizationControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspaces & Projects'),
        actions: [
          IconButton(
            tooltip: 'New workspace',
            onPressed: () => _newWorkspace(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(Icons.offline_bolt_rounded, size: 16),
              label: Text('Offline first'),
            ),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Organization could not load: $error')),
        data: (value) => _OrganizationShell(state: value),
      ),
    );
  }
}

class _OrganizationShell extends StatelessWidget {
  const _OrganizationShell({required this.state});
  final OrganizationState state;

  @override
  Widget build(BuildContext context) {
    final sidebar = _OrganizationSidebar(state: state);
    final content = _OrganizationContent(state: state);
    if (MediaQuery.sizeOf(context).width >= 1050) {
      return Row(
        children: [
          SizedBox(width: 290, child: sidebar),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(height: 220, child: sidebar),
        const Divider(height: 1),
        Expanded(child: content),
      ],
    );
  }
}

class _OrganizationSidebar extends ConsumerWidget {
  const _OrganizationSidebar({required this.state});
  final OrganizationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(organizationControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('System map',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'New workspace',
                onPressed: () => _newWorkspace(context, ref),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('WORKSPACES',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          Expanded(
            child: ListView(
              children: [
                for (final workspace in state.workspaces)
                  ListTile(
                    selected: workspace.id == state.selectedWorkspaceId,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: workspace.accentColor,
                      child: const Icon(Icons.workspaces_outlined,
                          size: 16, color: Colors.white),
                    ),
                    title: Text(workspace.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                        '${state.projects.where((project) => project.workspaceId == workspace.id && !project.archived).length}'),
                    onTap: () => controller.selectWorkspace(workspace.id),
                  ),
                const Divider(),
                Row(
                  children: [
                    Text('PROJECTS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'New project',
                      onPressed: () => _newProject(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
                for (final project in state.workspaceProjects)
                  ListTile(
                    dense: true,
                    selected: project.id == state.selectedProjectId,
                    leading: Icon(Icons.folder_special_outlined,
                        color: project.accentColor),
                    title: Text(project.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${project.progress.toStringAsFixed(0)}% · ${project.status.replaceAll('_', ' ')}'),
                    onTap: () => controller.selectProject(project.id),
                  ),
                const Divider(),
                Row(
                  children: [
                    Text('GOALS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'New goal',
                      onPressed: () => _newGoal(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
                for (final goal in state.workspaceGoals)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.flag_outlined,
                        color: Color(0xFFB45309)),
                    title: Text(goal.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${goal.progress.toStringAsFixed(0)}% · ${goal.goalType.replaceAll('_', ' ')}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationContent extends ConsumerWidget {
  const _OrganizationContent({required this.state});
  final OrganizationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = state.selectedWorkspace;
    final project = state.selectedProject;
    if (workspace == null) {
      return const Center(child: Text('Create a workspace to begin.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: workspace.accentColor,
                child:
                    const Icon(Icons.workspaces_outlined, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workspace.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(workspace.description.isEmpty
                      ? 'A calm organizational layer for your work.'
                      : workspace.description),
                ],
              ),
            ),
            FilledButton.tonalIcon(
                onPressed: () => _newProject(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New project')),
          ],
        ),
        const SizedBox(height: 18),
        _WorkspaceSummary(state: state),
        const SizedBox(height: 20),
        if (project == null)
          _WorkspaceEmpty(state: state)
        else
          _ProjectWorkspace(state: state, project: project),
      ],
    );
  }
}

class _WorkspaceSummary extends StatelessWidget {
  const _WorkspaceSummary({required this.state});
  final OrganizationState state;

  @override
  Widget build(BuildContext context) {
    final projects = state.workspaceProjects;
    final goals = state.workspaceGoals;
    final active =
        projects.where((project) => project.status == 'active').length;
    final progress = projects.isEmpty
        ? 0.0
        : projects.map((project) => project.progress).reduce((a, b) => a + b) /
            projects.length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
            label: 'Projects',
            value: '${projects.length}',
            icon: Icons.folder_open_rounded,
            color: const Color(0xFF0F766E)),
        _SummaryCard(
            label: 'Active',
            value: '$active',
            icon: Icons.play_circle_outline_rounded,
            color: const Color(0xFF0369A1)),
        _SummaryCard(
            label: 'Goals',
            value: '${goals.length}',
            icon: Icons.flag_outlined,
            color: const Color(0xFFB45309)),
        _SummaryCard(
            label: 'Average progress',
            value: '${progress.toStringAsFixed(0)}%',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF4F46E5)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceEmpty extends ConsumerWidget {
  const _WorkspaceEmpty({required this.state});
  final OrganizationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.account_tree_outlined, size: 56),
            const SizedBox(height: 12),
            Text('Build your system map',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Projects connect milestones, tasks, notes, calendar events, and goals. Start with a project and keep the hierarchy visible.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: () => _newProject(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create project')),
          ],
        ),
      ),
    );
  }
}

class _ProjectWorkspace extends ConsumerWidget {
  const _ProjectWorkspace({required this.state, required this.project});
  final OrganizationState state;
  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(organizationControllerProvider.notifier);
    final milestones = state.milestonesFor(project.id);
    final views = [
      'dashboard',
      'list',
      'kanban',
      'timeline',
      'calendar',
      'table',
      'gallery'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: 8,
                height: 56,
                decoration: BoxDecoration(
                    color: project.accentColor,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(project.description.isEmpty
                      ? 'Project control center'
                      : project.description),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    Chip(label: Text(project.status.replaceAll('_', ' '))),
                    Chip(label: Text(project.priority))
                  ]),
                ],
              ),
            ),
            OutlinedButton.icon(
                onPressed: () => _newMilestone(context, ref),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Milestone')),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: [
              for (final view in views)
                ButtonSegment(
                    value: view,
                    label: Text(view[0].toUpperCase() + view.substring(1)),
                    icon: Icon(_viewIcon(view)))
            ],
            selected: {state.projectView},
            onSelectionChanged: (selection) =>
                controller.selectProjectView(selection.first),
          ),
        ),
        const SizedBox(height: 16),
        _ProjectMetrics(
            project: project,
            milestones: milestones,
            progress: state.progressFor(project)),
        const SizedBox(height: 16),
        _ProjectViewBody(
            state: state, project: project, milestones: milestones),
      ],
    );
  }
}

class _ProjectMetrics extends StatelessWidget {
  const _ProjectMetrics(
      {required this.project,
      required this.milestones,
      required this.progress});
  final ProjectModel project;
  final List<MilestoneModel> milestones;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric(
            label: 'Progress',
            value: '${progress.toStringAsFixed(0)}%',
            color: project.accentColor),
        _Metric(
            label: 'Milestones',
            value: '${milestones.length}',
            color: const Color(0xFFB45309)),
        _Metric(
            label: 'Linked tasks',
            value: '${project.linkedTaskIds.length}',
            color: const Color(0xFF0369A1)),
        _Metric(
            label: 'Deadline',
            value: project.deadline == null
                ? 'Not set'
                : _shortDate(project.deadline!),
            color: const Color(0xFFBE123C)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, color: color))
          ]),
        ),
      ),
    );
  }
}

class _ProjectViewBody extends ConsumerWidget {
  const _ProjectViewBody(
      {required this.state, required this.project, required this.milestones});
  final OrganizationState state;
  final ProjectModel project;
  final List<MilestoneModel> milestones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.projectView) {
      case 'list':
        return _ProjectListView(projects: state.workspaceProjects);
      case 'kanban':
        return _KanbanView(projects: state.workspaceProjects);
      case 'timeline':
        return _TimelineView(milestones: milestones);
      case 'calendar':
        return _CalendarView(project: project, milestones: milestones);
      case 'table':
        return _TableView(projects: state.workspaceProjects);
      case 'gallery':
        return _GalleryView(projects: state.workspaceProjects);
      default:
        return _ProjectDashboardView(
            state: state, project: project, milestones: milestones);
    }
  }
}

class _ProjectDashboardView extends ConsumerWidget {
  const _ProjectDashboardView(
      {required this.state, required this.project, required this.milestones});
  final OrganizationState state;
  final ProjectModel project;
  final List<MilestoneModel> milestones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = state.goals
        .where((goal) => project.linkedGoalIds.contains(goal.id))
        .toList();
    final risk = project.deadline != null &&
        project.progress < 60 &&
        project.deadline!.difference(DateTime.now()).inDays <= 14;
    final progress = state.progressFor(project);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Project pulse',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                          value: (progress / 100).clamp(0, 1),
                          minHeight: 10,
                          color: project.accentColor,
                          backgroundColor:
                              project.accentColor.withValues(alpha: 0.14)),
                      const SizedBox(height: 10),
                      Text(
                          '${progress.toStringAsFixed(0)}% complete · ${risk ? 'Review deadline risk' : 'On track for current data'}'),
                      const SizedBox(height: 14),
                      Text(
                          'Local reasoning: progress is derived from milestone completion when milestones exist; otherwise the project’s saved progress is used.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                color: risk ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          risk
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          color: risk
                              ? const Color(0xFFBE123C)
                              : const Color(0xFF047857)),
                      const SizedBox(height: 10),
                      Text(
                          risk
                              ? 'Deadline needs attention'
                              : 'Planning looks steady',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(risk
                          ? 'Protect the next focus block and review the critical path.'
                          : 'Keep the next action connected to a milestone and goal.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Milestones',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (milestones.isEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.flag_outlined),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text(
                        'No milestones yet. Add the next meaningful checkpoint to make progress measurable.')),
                OutlinedButton(
                    onPressed: () => _newMilestone(context, ref),
                    child: const Text('Add'))
              ]),
            ),
          )
        else
          ...milestones.map((milestone) => _MilestoneTile(
              milestone: milestone,
              projectColor: project.accentColor,
              onChanged: (value) => ref
                  .read(organizationControllerProvider.notifier)
                  .updateMilestone(value))),
        const SizedBox(height: 16),
        Text('Connected goals',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (goals.isEmpty)
          const Card(
              elevation: 0,
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No goals linked yet. Link the project to a goal to make progress meaningful across the system.')))
        else
          ...goals.map((goal) => _GoalLinkTile(goal: goal)),
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile(
      {required this.milestone,
      required this.projectColor,
      required this.onChanged});
  final MilestoneModel milestone;
  final Color projectColor;
  final ValueChanged<MilestoneModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: milestone.completed
              ? const Color(0xFF047857)
              : projectColor.withValues(alpha: 0.12),
          child: Icon(
              milestone.completed ? Icons.check_rounded : Icons.flag_outlined,
              color: milestone.completed ? Colors.white : projectColor,
              size: 18),
        ),
        title: Text(milestone.name,
            style: TextStyle(
                decoration:
                    milestone.completed ? TextDecoration.lineThrough : null)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: (milestone.progress / 100).clamp(0, 1),
              color: projectColor,
              backgroundColor: projectColor.withValues(alpha: 0.14)),
          const SizedBox(height: 4),
          Text(
              '${milestone.progress.toStringAsFixed(0)}%${milestone.deadline == null ? '' : ' · due ${_shortDate(milestone.deadline!)}'}')
        ]),
        trailing: PopupMenuButton<double>(
            onSelected: (value) => onChanged(
                milestone.copyWith(progress: value, completed: value >= 100)),
            itemBuilder: (context) => const [
                  PopupMenuItem(value: 0, child: Text('0%')),
                  PopupMenuItem(value: 50, child: Text('50%')),
                  PopupMenuItem(value: 100, child: Text('Complete'))
                ]),
      ),
    );
  }
}

class _GoalLinkTile extends StatelessWidget {
  const _GoalLinkTile({required this.goal});
  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.flag_outlined, color: Color(0xFFB45309)),
        title: Text(goal.title),
        subtitle: Text(
            '${goal.goalType} · ${goal.progress.toStringAsFixed(0)}% complete'),
        trailing: SizedBox(
            width: 90,
            child: LinearProgressIndicator(
                value: (goal.progress / 100).clamp(0, 1),
                color: const Color(0xFFB45309),
                backgroundColor: const Color(0xFFFFEDD5))),
      ),
    );
  }
}

class _ProjectListView extends StatelessWidget {
  const _ProjectListView({required this.projects});
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final project in projects)
          Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(Icons.folder_special_outlined,
                  color: project.accentColor),
              title: Text(project.name),
              subtitle: Text(
                  '${project.status.replaceAll('_', ' ')} · ${project.priority} · ${project.progress.toStringAsFixed(0)}%'),
              trailing: SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                      value: (project.progress / 100).clamp(0, 1),
                      color: project.accentColor,
                      backgroundColor:
                          project.accentColor.withValues(alpha: 0.14))),
            ),
          ),
      ],
    );
  }
}

class _KanbanView extends StatelessWidget {
  const _KanbanView({required this.projects});
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    const statuses = ['planning', 'active', 'waiting', 'completed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in statuses)
            SizedBox(
              width: 230,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(status.replaceAll('_', ' ').toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final project
                            in projects.where((item) => item.status == status))
                          Card(
                            color: project.accentColor.withValues(alpha: 0.10),
                            elevation: 0,
                            child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(project.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      Text(
                                          '${project.progress.toStringAsFixed(0)}% complete')
                                    ])),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.milestones});
  final List<MilestoneModel> milestones;

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: milestones.isEmpty
                ? const Text('Add milestones to see the project timeline.')
                : Column(children: [
                    for (final milestone in milestones)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: milestone.completed
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF4F46E5),
                                  shape: BoxShape.circle)),
                          title: Text(milestone.name),
                          subtitle: Text(milestone.deadline == null
                              ? 'No deadline'
                              : _shortDate(milestone.deadline!)),
                          trailing:
                              Text('${milestone.progress.toStringAsFixed(0)}%'))
                  ])));
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({required this.project, required this.milestones});
  final ProjectModel project;
  final List<MilestoneModel> milestones;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, DateTime date, double progress})>[
      for (final milestone in milestones)
        if (milestone.deadline != null)
          (
            label: 'Milestone: ${milestone.name}',
            date: milestone.deadline!,
            progress: milestone.progress
          ),
      if (project.deadline != null)
        (
          label: 'Project deadline',
          date: project.deadline!,
          progress: project.progress
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: entries.isEmpty
                ? const Text('No project or milestone deadlines are set.')
                : Column(children: [
                    for (final entry in entries)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_outlined,
                              color: Color(0xFFBE123C)),
                          title: Text(entry.label),
                          subtitle: Text(_shortDate(entry.date)),
                          trailing:
                              Text('${entry.progress.toStringAsFixed(0)}%'))
                  ])));
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.projects});
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Project')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Progress')),
          ],
          rows: [
            for (final project in projects)
              DataRow(
                cells: [
                  DataCell(Text(project.name)),
                  DataCell(Text(project.status.replaceAll('_', ' '))),
                  DataCell(Text(project.priority)),
                  DataCell(Text('${project.progress.toStringAsFixed(0)}%')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GalleryView extends StatelessWidget {
  const _GalleryView({required this.projects});
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final project in projects)
        SizedBox(
            width: 240,
            child: Card(
                elevation: 0,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 8,
                              decoration: BoxDecoration(
                                  color: project.accentColor,
                                  borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 14),
                          Text(project.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(
                              project.description.isEmpty
                                  ? 'No description'
                                  : project.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 14),
                          Text(
                              '${project.progress.toStringAsFixed(0)}% complete')
                        ]))))
    ]);
  }
}

Future<void> _newWorkspace(BuildContext context, WidgetRef ref) async {
  final values = await _form(context,
      title: 'New workspace',
      nameHint: 'Personal, College, Startup…',
      descriptionHint: 'What belongs here?');
  if (values != null) {
    await ref
        .read(organizationControllerProvider.notifier)
        .createWorkspace(values.$1, values.$2);
  }
}

Future<void> _newProject(BuildContext context, WidgetRef ref) async {
  final values = await _form(context,
      title: 'New project',
      nameHint: 'Project name',
      descriptionHint: 'What outcome will this project deliver?');
  if (values != null) {
    await ref
        .read(organizationControllerProvider.notifier)
        .createProject(values.$1, values.$2);
  }
}

Future<void> _newGoal(BuildContext context, WidgetRef ref) async {
  final values = await _form(context,
      title: 'New goal',
      nameHint: 'Goal title',
      descriptionHint: 'What does success look like?');
  if (values != null) {
    await ref
        .read(organizationControllerProvider.notifier)
        .createGoal(values.$1, values.$2);
  }
}

Future<void> _newMilestone(BuildContext context, WidgetRef ref) async {
  final values = await _form(context,
      title: 'New milestone', nameHint: 'Milestone name', descriptionHint: '');
  if (values != null) {
    await ref
        .read(organizationControllerProvider.notifier)
        .createMilestone(values.$1);
  }
}

Future<(String, String)?> _form(BuildContext context,
    {required String title,
    required String nameHint,
    required String descriptionHint}) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: nameHint, border: const OutlineInputBorder())),
          if (descriptionHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
                controller: description,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: descriptionHint,
                    border: const OutlineInputBorder())),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, name.text.trim().isNotEmpty),
            child: const Text('Create')),
      ],
    ),
  );
  final values =
      result == true ? (name.text.trim(), description.text.trim()) : null;
  name.dispose();
  description.dispose();
  return values;
}

IconData _viewIcon(String view) {
  switch (view) {
    case 'dashboard':
      return Icons.dashboard_outlined;
    case 'list':
      return Icons.view_list_outlined;
    case 'kanban':
      return Icons.view_kanban_outlined;
    case 'timeline':
      return Icons.timeline_outlined;
    case 'calendar':
      return Icons.calendar_month_outlined;
    case 'table':
      return Icons.table_chart_outlined;
    case 'gallery':
      return Icons.grid_view_outlined;
    default:
      return Icons.dashboard_outlined;
  }
}

String _shortDate(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';
