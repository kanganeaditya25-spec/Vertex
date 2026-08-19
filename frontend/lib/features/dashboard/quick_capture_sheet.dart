import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../calendar/calendar_providers.dart';
import '../notes/notes_providers.dart';
import '../organization/organization_providers.dart';
import '../reminders/reminder_providers.dart';
import '../tasks/task_providers.dart';

class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key, this.initialType = 'Task'});

  final String initialType;

  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  late final TextEditingController _textController;
  late String _type;
  bool _saving = false;

  static const _types = ['Task', 'Note', 'Reminder', 'Calendar', 'Project'];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _type = _types.contains(widget.initialType) ? widget.initialType : 'Task';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Quick Capture',
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Close Quick Capture',
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                  'Get it out of your head now. Add structure later when you have attention for it.'),
              const SizedBox(height: 16),
              Semantics(
                label: 'Capture type',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _types)
                      ChoiceChip(
                          label: Text(type),
                          selected: _type == type,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _type = type)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _textController,
                autofocus: true,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: _type == 'Task'
                      ? 'What needs to happen?'
                      : 'What do you want to capture?',
                  hintText: _type == 'Task'
                      ? 'Write the next visible action'
                      : 'Keep it short; you can add detail later',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: Text(
                      _saving ? 'Saving…' : 'Capture ${_type.toLowerCase()}'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _save() async {
    final title = _textController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Write one short sentence before capturing.')));
      return;
    }
    setState(() => _saving = true);
    try {
      switch (_type) {
        case 'Task':
          await ref.read(taskControllerProvider.future);
          await ref
              .read(taskControllerProvider.notifier)
              .createTask(title: title);
        case 'Note':
          await ref.read(notesControllerProvider.future);
          await ref
              .read(notesControllerProvider.notifier)
              .createNote(title: title);
        case 'Reminder':
          await ref.read(reminderControllerProvider.future);
          await ref.read(reminderControllerProvider.notifier).create(
              title: title,
              nextTriggerAt: DateTime.now().add(const Duration(hours: 1)),
              linkedModule: 'quick_capture');
        case 'Calendar':
          await ref.read(calendarControllerProvider.future);
          final start = DateTime.now().add(const Duration(minutes: 30));
          await ref.read(calendarControllerProvider.notifier).createEvent(
              title: title,
              startAt: start,
              endAt: start.add(const Duration(minutes: 30)),
              eventType: 'quick_capture');
        case 'Project':
          await ref.read(organizationControllerProvider.future);
          await ref
              .read(organizationControllerProvider.notifier)
              .createProject(title, 'Captured from Quick Capture');
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$_type captured offline.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
