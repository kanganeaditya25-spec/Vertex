import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'task_models.dart';
import 'task_providers.dart';

class TaskHomePage extends ConsumerWidget {
  const TaskHomePage({super.key, this.projectId});
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Tasks'),
        actions: [
          IconButton(
              tooltip: 'Sort tasks',
              onPressed: () => _showSortMenu(context, ref),
              icon: const Icon(Icons.sort_rounded)),
          IconButton(
              tooltip: 'New task',
              onPressed: () =>
                  _showTaskEditor(context, ref, projectId: projectId),
              icon: const Icon(Icons.add_task_rounded)),
        ],
      ),
      body: taskState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(taskControllerProvider)),
        data: (state) => _TaskWorkspace(state: state, projectId: projectId),
      ),
    );
  }
}

class _TaskWorkspace extends ConsumerWidget {
  const _TaskWorkspace({required this.state, this.projectId});

  final TaskState state;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskControllerProvider.notifier);
    final visibleTasks = state.visibleTasksFor(projectId);
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(taskControllerProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
              projectId == null
                  ? 'A calmer way to decide what to do next.'
                  : 'Tasks connected to this project.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          TextField(
            onChanged: controller.setQuery,
            decoration: InputDecoration(
              hintText: 'Search tasks, tags, projects…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => controller.setQuery(''),
                      icon: const Icon(Icons.clear_rounded)),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          _FilterBar(state: state),
          const SizedBox(height: 16),
          _TodaySummary(state: state),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Task list',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (state.selectedIds.isNotEmpty) ...[
                Text('${state.selectedIds.length} selected'),
                IconButton(
                    tooltip: 'Complete selected',
                    onPressed: controller.bulkComplete,
                    icon: const Icon(Icons.done_all_rounded)),
                IconButton(
                    tooltip: 'Clear selection',
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.close_rounded)),
              ] else
                Text('${visibleTasks.length} visible',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (visibleTasks.isEmpty)
            _EmptyTasks(
                onCreate: () =>
                    _showTaskEditor(context, ref, projectId: projectId),
                hasQuery: state.query.isNotEmpty)
          else
            ...visibleTasks.map(
              (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskCard(
                      task: task,
                      selected: state.selectedIds.contains(task.id))),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.state});
  final TaskState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskControllerProvider.notifier);
    final filters = <String, String?>{
      'All': null,
      'Today': 'today',
      'In progress': 'in_progress',
      'Blocked': 'blocked',
      'Completed': 'completed'
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = entry.value == state.statusFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.key),
              selected: selected,
              onSelected: (_) => controller.setStatusFilter(entry.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.state});
  final TaskState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = state.tasks.where((task) => !task.isArchived).length;
    final progress = total == 0 ? 0.0 : state.completedCount / total;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text('Your progress today',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'Start with one meaningful next action.'
                : '${state.completedCount} of $total tasks complete · ${(progress * 100).round()}% through today',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(children: [
            _Metric(label: 'Remaining', value: '${state.remainingCount}'),
            _Metric(label: 'Completed', value: '${state.completedCount}'),
            _Metric(label: 'Urgent', value: '${state.urgentCount}'),
            _Metric(label: 'Progress', value: '${(progress * 100).round()}%'),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall)
      ]));
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.selected});
  final TaskModel task;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskControllerProvider.notifier);
    final priorityColor = _priorityColor(context, task.priority);
    return Card(
      elevation: selected ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTaskDetails(context, ref, task),
        onLongPress: () => controller.toggleSelection(task.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
                value: task.isCompleted,
                onChanged: (_) => controller.toggleComplete(task)),
            Container(
                width: 4,
                height: 68,
                margin: const EdgeInsets.only(right: 12, top: 4),
                decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(8))),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(task.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    fontWeight: FontWeight.w700))),
                    if (task.pinned)
                      const Icon(Icons.push_pin_rounded, size: 17),
                    if (task.favorite)
                      const Icon(Icons.star_rounded,
                          size: 18, color: Colors.amber)
                  ]),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(task.description,
                        maxLines: 2, overflow: TextOverflow.ellipsis)
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Tag(text: task.priority, color: priorityColor),
                    _Tag(text: task.category),
                    if (task.deadline != null)
                      _Tag(
                          text: DateFormat.MMMd().format(task.deadline!),
                          icon: Icons.schedule_rounded),
                    if (task.estimatedMinutes > 0)
                      _Tag(
                          text: '${task.estimatedMinutes}m',
                          icon: Icons.timer_outlined),
                    if (task.riskScore >= 50)
                      _Tag(
                          text: 'risk ${task.riskScore.round()}',
                          color: Theme.of(context).colorScheme.error),
                  ]),
                  if (task.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(task.explanation,
                        style: Theme.of(context).textTheme.bodySmall)
                  ],
                ])),
            PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, ref, task, action),
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pin', child: Text('Pin / unpin')),
                      PopupMenuItem(
                          value: 'favorite',
                          child: Text('Favorite / unfavorite')),
                      PopupMenuItem(
                          value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                      PopupMenuItem(value: 'delete', child: Text('Delete'))
                    ]),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Chip(
      avatar: icon == null ? null : Icon(icon, size: 14),
      label: Text(text),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor:
          (color ?? Theme.of(context).colorScheme.surfaceContainerHighest)
              .withValues(alpha: 0.65));
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.onCreate, required this.hasQuery});
  final VoidCallback onCreate;
  final bool hasQuery;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            Icon(hasQuery ? Icons.search_off_rounded : Icons.task_alt_rounded,
                size: 48),
            const SizedBox(height: 12),
            Text(
                hasQuery
                    ? 'Nothing matches that search'
                    : 'You have a clear starting point',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(hasQuery
                ? 'Try another phrase or clear the filters.'
                : 'Capture the smallest next action and build momentum.'),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create task'))
          ])));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            const Text('Your work is safe',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
                'We couldn’t load tasks right now. Try again when you’re ready.'),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'))
          ])));
}

Color _priorityColor(BuildContext context, String priority) =>
    switch (priority) {
      'critical' => Theme.of(context).colorScheme.error,
      'urgent' => Colors.deepOrange,
      'high' => Colors.orange,
      'low' => Colors.blueGrey,
      'someday' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary
    };

Future<void> _showTaskEditor(BuildContext context, WidgetRef ref,
    {String? projectId}) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  var priority = 'medium';
  DateTime? deadline;
  var canCreate = false;

  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Create task'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  onChanged: (value) =>
                      setState(() => canCreate = value.trim().isNotEmpty),
                  decoration: const InputDecoration(
                      labelText: 'What needs to happen?',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Context or next action',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked =
                            await _pickDateTime(context, initial: deadline);
                        if (picked != null) setState(() => deadline = picked);
                      },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(deadline == null
                          ? 'Schedule for a date'
                          : DateFormat.yMMMd().add_jm().format(deadline!)),
                    ),
                  ),
                  if (deadline != null)
                    IconButton(
                        tooltip: 'Clear scheduled date',
                        onPressed: () => setState(() => deadline = null),
                        icon: const Icon(Icons.clear_rounded)),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                      labelText: 'Priority', border: OutlineInputBorder()),
                  items: const [
                    'critical',
                    'urgent',
                    'high',
                    'medium',
                    'low',
                    'someday'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => priority = value ?? priority),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed:
                  canCreate ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text('Create')),
        ],
      ),
    ),
  );

  if (created == true && titleController.text.trim().isNotEmpty) {
    await ref.read(taskControllerProvider.notifier).createTask(
        title: titleController.text,
        description: descriptionController.text,
        priority: priority,
        deadline: deadline,
        projectId: projectId);
  }
  titleController.dispose();
  descriptionController.dispose();
}

Future<void> _showTaskDetails(
    BuildContext context, WidgetRef ref, TaskModel task) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(task.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.description.isEmpty
                  ? 'No description'
                  : task.description),
              const SizedBox(height: 16),
              Text('Why this matters',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(task.explanation.isEmpty
                  ? 'The local scoring engine will explain recommendations once more task signals are available.'
                  : task.explanation),
              if (task.checklist.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Checklist',
                    style: Theme.of(context).textTheme.titleSmall),
                ...task.checklist.map((item) => CheckboxListTile(
                    value: item.completed,
                    onChanged: null,
                    title: Text(item.text),
                    contentPadding: EdgeInsets.zero)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close')),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            ref.read(taskControllerProvider.notifier).toggleComplete(task);
          },
          child: Text(task.isCompleted ? 'Reopen' : 'Complete'),
        ),
      ],
    ),
  );
}

void _handleAction(
    BuildContext context, WidgetRef ref, TaskModel task, String action) {
  final controller = ref.read(taskControllerProvider.notifier);
  switch (action) {
    case 'pin':
      controller.togglePin(task);
    case 'favorite':
      controller.toggleFavorite(task);
    case 'duplicate':
      controller.duplicate(task);
    case 'archive':
      controller.archive(task);
    case 'delete':
      controller.deleteTask(task);
  }
}

Future<DateTime?> _pickDateTime(BuildContext context,
    {DateTime? initial}) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year, now.month, now.day);
  final initialDate = initial == null || initial.isBefore(firstDate)
      ? firstDate
      : DateTime(initial.year, initial.month, initial.day);
  final date = await showDatePicker(
    context: context,
    firstDate: firstDate,
    lastDate: firstDate.add(const Duration(days: 3650)),
    initialDate: initialDate,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
      context: context,
      initialTime:
          initial == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

void _showSortMenu(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['priority', 'deadline', 'created', 'title']
                  .map((sort) => ListTile(
                      title: Text(
                          'Sort by ${sort[0].toUpperCase()}${sort.substring(1)}'),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(taskControllerProvider.notifier).setSort(sort);
                      }))
                  .toList())));
}
