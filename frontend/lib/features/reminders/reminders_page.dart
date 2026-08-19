import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_models.dart';
import 'reminder_providers.dart';

class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key, this.projectId});
  final String? projectId;

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reminderControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Center'),
        actions: [
          IconButton(
              onPressed: () =>
                  ref.read(reminderControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh reminders'),
          IconButton(
              onPressed: () =>
                  _showCreateDialog(context, projectId: widget.projectId),
              icon: const Icon(Icons.add_alarm_rounded),
              tooltip: 'New reminder'),
          IconButton(
              onPressed: () => _showPreferences(context),
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Reminder preferences'),
          const SizedBox(width: 8),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load reminders: $error')),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(ReminderState state) {
    final controller = ref.read(reminderControllerProvider.notifier);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        children: [
          _header(context, state),
          const SizedBox(height: 16),
          _stats(state),
          const SizedBox(height: 18),
          TextField(
              controller: _searchController,
              onChanged: controller.setQuery,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText:
                      'Search reminders by title, module, category, or rule',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          _filters(state),
          if (state.smartSuggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _suggestions(state.smartSuggestions),
          ],
          const SizedBox(height: 16),
          if (state.selectedIds.isNotEmpty) _bulkBar(state),
          if (state.selectedIds.isNotEmpty) const SizedBox(height: 12),
          if (state.visibleRemindersFor(widget.projectId).isEmpty)
            _emptyState(state.filter),
          if (state.visibleRemindersFor(widget.projectId).isNotEmpty)
            _reminderGrid(state, wide, projectId: widget.projectId),
        ],
      );
    });
  }

  Widget _header(BuildContext context, ReminderState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.notifications_active_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('One place for every follow-up',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '${state.stats.active} active · ${state.stats.overdue} overdue · ${state.deliveredCount} local alerts delivered',
                      style: Theme.of(context).textTheme.bodyMedium)
                ])),
            if (state.preferences.quietHoursEnabled)
              const Chip(
                  avatar: Icon(Icons.nightlight_outlined, size: 16),
                  label: Text('Quiet hours')),
          ]),
        ),
      );

  Widget _stats(ReminderState state) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        _stat('Active', state.stats.active, Icons.alarm_on_outlined),
        _stat(
            'Today',
            state.visibleReminders
                .where((item) => _isToday(item.nextTriggerAt))
                .length,
            Icons.today_outlined),
        _stat('Overdue', state.stats.overdue, Icons.warning_amber_outlined),
        _stat('Completion', '${(state.stats.completionRate * 100).round()}%',
            Icons.check_circle_outline),
      ]);

  Widget _stat(String label, Object value, IconData icon) => SizedBox(
      width: 160,
      child: Card(
          child: ListTile(
              dense: true,
              leading: Icon(icon),
              title: Text('$value',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(label))));

  Widget _filters(ReminderState state) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final filter in const [
          'active',
          'today',
          'overdue',
          'completed',
          'dismissed',
          'history'
        ])
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                  label: Text(_label(filter)),
                  selected: state.filter == filter,
                  onSelected: (_) => ref
                      .read(reminderControllerProvider.notifier)
                      .setFilter(filter))),
      ]));

  Widget _suggestions(List<SmartSuggestionModel> suggestions) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Smart suggestions',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final suggestion in suggestions.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(suggestion.recommendation),
                subtitle: Text(suggestion.reason),
                trailing: Text('${(suggestion.confidence * 100).round()}%'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bulkBar(ReminderState state) {
    final controller = ref.read(reminderControllerProvider.notifier);
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Text('${state.selectedIds.length} selected'),
            const Spacer(),
            TextButton(
                onPressed: () => controller.bulkAction('complete'),
                child: const Text('Complete')),
            TextButton(
                onPressed: () => controller.bulkAction('snooze'),
                child: const Text('Snooze')),
            TextButton(
                onPressed: () => controller.bulkAction('archived'),
                child: const Text('Archive')),
            TextButton(
                onPressed: controller.clearSelection,
                child: const Text('Clear')),
          ],
        ),
      ),
    );
  }

  Widget _reminderGrid(ReminderState state, bool wide, {String? projectId}) {
    final visibleReminders = state.visibleRemindersFor(projectId);
    if (wide) {
      return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 520,
              mainAxisExtent: 190,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12),
          itemCount: visibleReminders.length,
          itemBuilder: (context, index) => _ReminderCard(
              reminder: visibleReminders[index],
              selected: state.selectedIds.contains(visibleReminders[index].id),
              onSelect: () => ref
                  .read(reminderControllerProvider.notifier)
                  .toggleSelection(visibleReminders[index].id),
              onComplete: () => ref
                  .read(reminderControllerProvider.notifier)
                  .complete(visibleReminders[index].id),
              onSnooze: () => _snooze(visibleReminders[index])));
    }
    return Column(children: [
      for (final reminder in visibleReminders)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReminderCard(
                reminder: reminder,
                selected: state.selectedIds.contains(reminder.id),
                onSelect: () => ref
                    .read(reminderControllerProvider.notifier)
                    .toggleSelection(reminder.id),
                onComplete: () => ref
                    .read(reminderControllerProvider.notifier)
                    .complete(reminder.id),
                onSnooze: () => _snooze(reminder)))
    ]);
  }

  Widget _emptyState(String filter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          children: [
            Icon(
              filter == 'overdue'
                  ? Icons.check_circle_outline
                  : Icons.notifications_none_rounded,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              filter == 'overdue'
                  ? 'Nothing is overdue'
                  : 'No reminders in this view',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
                'Create a reminder or change the filter to see scheduled work here.'),
          ],
        ),
      ),
    );
  }

  Future<void> _snooze(ReminderModel reminder) async {
    final minutes = await showModalBottomSheet<int>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final option in const [5, 10, 15, 30, 60])
                ListTile(
                    title: Text(option == 60 ? '1 hour' : '$option minutes'),
                    onTap: () => Navigator.pop(context, option))
            ])));
    if (minutes != null) {
      await ref
          .read(reminderControllerProvider.notifier)
          .snooze(reminder.id, minutes);
    }
  }

  Future<void> _showCreateDialog(BuildContext context,
      {String? projectId}) async {
    final result = await showDialog<_CreateReminderResult>(
        context: context, builder: (_) => const _CreateReminderDialog());
    if (result == null || !mounted) return;
    await ref.read(reminderControllerProvider.notifier).create(
        title: result.title,
        description: result.description,
        nextTriggerAt: result.when,
        priority: result.priority,
        category: result.category,
        repeatRule: result.repeatRule,
        projectId: projectId ?? '');
  }

  Future<void> _showPreferences(BuildContext context) async {
    final current = ref.read(reminderControllerProvider).valueOrNull;
    if (current == null) return;
    final updated = await showDialog<ReminderPreferencesModel>(
        context: context,
        builder: (_) => _PreferencesDialog(value: current.preferences));
    if (updated != null) {
      await ref
          .read(reminderControllerProvider.notifier)
          .savePreferences(updated);
    }
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard(
      {required this.reminder,
      required this.selected,
      required this.onSelect,
      required this.onComplete,
      required this.onSnooze});
  final ReminderModel reminder;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final color = reminder.isOverdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: selected, onChanged: (_) => onSelect()),
            Icon(
              reminder.isOverdue
                  ? Icons.warning_amber_rounded
                  : Icons.alarm_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    reminder.description.isEmpty
                        ? '${_label(reminder.linkedModule)} · ${_label(reminder.category)}'
                        : reminder.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(label: Text(_timeLabel(reminder.nextTriggerAt))),
                      Chip(label: Text('P${reminder.priority}')),
                      if (reminder.repeatRule.isNotEmpty)
                        const Chip(label: Text('Recurring')),
                      if (reminder.aiGenerated)
                        const Chip(label: Text('AI suggested')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Complete'),
                      ),
                      TextButton.icon(
                        onPressed: onSnooze,
                        icon: const Icon(Icons.snooze_outlined, size: 16),
                        label: const Text('Snooze'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateReminderResult {
  const _CreateReminderResult(this.title, this.description, this.when,
      this.priority, this.category, this.repeatRule);
  final String title;
  final String description;
  final DateTime? when;
  final int priority;
  final String category;
  final Map<String, dynamic> repeatRule;
}

class _CreateReminderDialog extends StatefulWidget {
  const _CreateReminderDialog();
  @override
  State<_CreateReminderDialog> createState() => _CreateReminderDialogState();
}

class _CreateReminderDialogState extends State<_CreateReminderDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _when;
  int _priority = 3;
  String _category = 'general';
  String _repeat = 'none';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New reminder'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (var value = 1; value <= 5; value++)
                    DropdownMenuItem(
                        value: value, child: Text('Priority $value')),
                ],
                onChanged: (value) => setState(() => _priority = value ?? 3),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'review', child: Text('Review')),
                  DropdownMenuItem(value: 'study', child: Text('Study')),
                  DropdownMenuItem(
                      value: 'follow_up', child: Text('Follow-up')),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? 'general'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _repeat,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('One time')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (value) => setState(() => _repeat = value ?? 'none'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                    _when == null ? 'Choose trigger time' : _timeLabel(_when)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _title.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _CreateReminderResult(
                      _title.text.trim(),
                      _description.text.trim(),
                      _when,
                      _priority,
                      _category,
                      _repeat == 'none' ? const {} : {'kind': _repeat},
                    ),
                  ),
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        initialDate: DateTime.now());
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      setState(() => _when =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }
}

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog({required this.value});
  final ReminderPreferencesModel value;
  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late bool _quiet;
  late bool _silent;
  @override
  void initState() {
    super.initState();
    _quiet = widget.value.quietHoursEnabled;
    _silent = widget.value.silentMode;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Reminder preferences'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
                value: _quiet,
                onChanged: (value) => setState(() => _quiet = value),
                title: const Text('Quiet hours')),
            SwitchListTile(
                value: _silent,
                onChanged: (value) => setState(() => _silent = value),
                title: const Text('Silent mode')),
            const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Non-critical alerts are delayed during quiet hours.'))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(
                    context,
                    widget.value.copyWith(
                        quietHoursEnabled: _quiet, silentMode: _silent)),
                child: const Text('Save'))
          ]);
}

bool _isToday(DateTime? value) {
  if (value == null) return false;
  final now = DateTime.now();
  return value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
}

String _timeLabel(DateTime? value) => value == null
    ? 'Unscheduled'
    : '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
