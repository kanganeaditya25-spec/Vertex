import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'calendar_models.dart';
import 'calendar_providers.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key, this.projectId});
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(calendarControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: calendar.maybeWhen(
            data: (state) =>
                Text(DateFormat.yMMMM().format(state.selectedDate)),
            orElse: () => const Text('Calendar & Time')),
        actions: [
          IconButton(
              tooltip: 'Jump to today',
              onPressed: () => ref
                  .read(calendarControllerProvider.notifier)
                  .selectDate(DateTime.now()),
              icon: const Icon(Icons.today_rounded)),
          IconButton(
              tooltip: 'New event',
              onPressed: () => _showEventEditor(context, ref,
                  projectId: projectId,
                  initialDate: calendar.maybeWhen(
                      data: (state) => state.selectedDate,
                      orElse: DateTime.now)),
              icon: const Icon(Icons.add_rounded)),
          IconButton(
              tooltip: 'Calendar preferences',
              onPressed: () => _showPreferences(context, ref),
              icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: calendar.when(
        loading: () => const _CalendarLoading(),
        error: (error, _) => _CalendarError(
            message: error.toString(),
            retry: () => ref.invalidate(calendarControllerProvider)),
        data: (state) => _CalendarWorkspace(state: state, projectId: projectId),
      ),
    );
  }
}

class _CalendarWorkspace extends ConsumerWidget {
  const _CalendarWorkspace({required this.state, this.projectId});
  final CalendarState state;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final scopedState = state.forProject(projectId);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(calendarControllerProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text('Plan your energy, not just your hours.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          TextField(
            onChanged: controller.setQuery,
            decoration: InputDecoration(
                hintText: 'Search events, locations, categories…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => controller.setQuery(''),
                        icon: const Icon(Icons.clear_rounded)),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 12),
          _ViewSwitcher(state: state),
          if (state.conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ConflictBanner(conflicts: state.conflicts)
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
              duration: state.preferences.reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: _viewFor(context, ref, scopedState, projectId)),
        ],
      ),
    );
  }
}

Widget _viewFor(BuildContext context, WidgetRef ref, CalendarState state,
        String? projectId) =>
    switch (state.view) {
      'day' => _DayView(state: state, projectId: projectId),
      'month' => _MonthView(state: state, projectId: projectId),
      'agenda' => _AgendaView(state: state, projectId: projectId),
      _ => _WeekView(state: state, projectId: projectId),
    };

class _ViewSwitcher extends ConsumerWidget {
  const _ViewSwitcher({required this.state});
  final CalendarState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: ['week', 'day', 'month', 'agenda']
                .map((view) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(view[0].toUpperCase() + view.substring(1)),
                        selected: state.view == view,
                        onSelected: (_) => controller.setView(view))))
                .toList()));
  }
}

class _AgendaView extends ConsumerWidget {
  const _AgendaView({required this.state, this.projectId});
  final CalendarState state;
  final String? projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = state.visibleEvents;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SummaryPanel(state: state),
      const SizedBox(height: 18),
      Row(children: [
        Text('Upcoming plan',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('${events.length} events',
            style: Theme.of(context).textTheme.bodySmall)
      ]),
      const SizedBox(height: 8),
      if (events.isEmpty)
        _EmptyCalendar(
            onCreate: () =>
                _showEventEditor(context, ref, projectId: projectId),
            message: state.query.isEmpty
                ? 'Your schedule has room for something meaningful.'
                : 'No events match that search.')
      else
        ...events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventCard(event: event))),
    ]);
  }
}

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.state, this.projectId});
  final CalendarState state;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = _startOfWeek(state.selectedDate,
        firstDayOfWeek: state.preferences.firstDayOfWeek);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WeekNavigator(state: state, weekStart: weekStart),
      const SizedBox(height: 12),
      _SummaryPanel(state: state),
      const SizedBox(height: 12),
      _WeekGrid(state: state, weekStart: weekStart),
    ]);
  }
}

class _DayView extends ConsumerWidget {
  const _DayView({required this.state, this.projectId});
  final CalendarState state;
  final String? projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = state.selectedDayEvents;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DateNavigator(state: state),
      const SizedBox(height: 12),
      _SummaryPanel(state: state),
      const SizedBox(height: 18),
      if (events.isEmpty)
        _EmptyCalendar(
            onCreate: () =>
                _showEventEditor(context, ref, projectId: projectId),
            message: 'No events are scheduled for this day.')
      else
        ...events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventCard(event: event))),
    ]);
  }
}

class _MonthView extends ConsumerWidget {
  const _MonthView({required this.state, this.projectId});
  final CalendarState state;
  final String? projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    return Column(children: [
      CalendarDatePicker(
          initialDate: state.selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
          onDateChanged: controller.selectDate),
      const SizedBox(height: 8),
      _DateNavigator(state: state),
      const SizedBox(height: 12),
      ...state.selectedDayEvents.map((event) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EventCard(event: event))),
      if (state.selectedDayEvents.isEmpty)
        _EmptyCalendar(
            onCreate: () =>
                _showEventEditor(context, ref, projectId: projectId),
            message: 'No events on the selected date.'),
    ]);
  }
}

class _WeekNavigator extends ConsumerWidget {
  const _WeekNavigator({required this.state, required this.weekStart});
  final CalendarState state;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range = weekStart.month == weekEnd.month
        ? '${DateFormat.MMMd().format(weekStart)}–${DateFormat.d().format(weekEnd)}, ${weekEnd.year}'
        : '${DateFormat.MMMd().format(weekStart)}–${DateFormat.MMMd().format(weekEnd)}, ${weekEnd.year}';
    return Row(children: [
      IconButton(
          tooltip: 'Previous week',
          onPressed: () => controller
              .selectDate(state.selectedDate.subtract(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_left_rounded)),
      IconButton(
          tooltip: 'Next week',
          onPressed: () => controller
              .selectDate(state.selectedDate.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right_rounded)),
      const SizedBox(width: 4),
      OutlinedButton(
          onPressed: () => controller.selectDate(DateTime.now()),
          child: const Text('Today')),
      Expanded(
          child: Center(
              child: Text(range,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)))),
    ]);
  }
}

class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({required this.state, required this.weekStart});
  final CalendarState state;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final startMinute = state.preferences.workStartMinute;
    final endMinute = state.preferences.workEndMinute;
    final rows = <Widget>[];
    for (var minute = startMinute; minute < endMinute; minute += 60) {
      rows.add(_WeekHourRow(
          state: state,
          weekStart: weekStart,
          minute: minute,
          onSelectDate: controller.selectDate));
    }
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 820),
          child: Column(children: [
            _WeekHeader(
                state: state,
                weekStart: weekStart,
                onSelectDate: controller.selectDate),
            ...rows,
          ]),
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader(
      {required this.state,
      required this.weekStart,
      required this.onSelectDate});
  final CalendarState state;
  final DateTime weekStart;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(width: 62, child: Center(child: Text(''))),
        for (var index = 0; index < 7; index++)
          Expanded(
              child: InkWell(
            onTap: () => onSelectDate(weekStart.add(Duration(days: index))),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: _sameDate(state.selectedDate,
                          weekStart.add(Duration(days: index)))
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  border: const Border(
                      bottom: BorderSide(color: Color(0xFFE2EAE5)))),
              child: Column(children: [
                Text(
                    DateFormat.E().format(weekStart.add(Duration(days: index))),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                    DateFormat.d().format(weekStart.add(Duration(days: index))),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
          )),
      ]);
}

class _WeekHourRow extends StatelessWidget {
  const _WeekHourRow(
      {required this.state,
      required this.weekStart,
      required this.minute,
      required this.onSelectDate});
  final CalendarState state;
  final DateTime weekStart;
  final int minute;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 74,
        child: Row(children: [
          SizedBox(
              width: 62,
              child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Text(_formatHour(minute),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall))),
          for (var index = 0; index < 7; index++)
            Expanded(
                child: _WeekDayCell(
                    state: state,
                    day: weekStart.add(Duration(days: index)),
                    minute: minute,
                    onSelectDate: onSelectDate)),
        ]),
      );
}

class _WeekDayCell extends ConsumerWidget {
  const _WeekDayCell(
      {required this.state,
      required this.day,
      required this.minute,
      required this.onSelectDate});
  final CalendarState state;
  final DateTime day;
  final int minute;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellEvents = state.visibleEvents.where((event) {
      if (!_sameDate(event.startAt, day)) return false;
      final start = event.startAt.hour * 60 + event.startAt.minute;
      final effectiveStart = start < state.preferences.workStartMinute
          ? state.preferences.workStartMinute
          : start;
      return effectiveStart >= minute && effectiveStart < minute + 60;
    }).toList();
    return InkWell(
      onTap: () => onSelectDate(day),
      child: Container(
        decoration: BoxDecoration(
            color: _sameDate(state.selectedDate, day)
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.035)
                : Colors.transparent,
            border: const Border(
                left: BorderSide(color: Color(0xFFE2EAE5)),
                top: BorderSide(color: Color(0xFFE2EAE5)))),
        padding: const EdgeInsets.all(2),
        child: Stack(children: [
          for (final event in cellEvents)
            Positioned(
                top: ((event.startAt.minute / 60) * 70).clamp(0, 70),
                left: 2,
                right: 2,
                height: (event.duration.inMinutes / 60 * 70)
                    .clamp(30, 138)
                    .toDouble(),
                child: _WeekEventChip(event: event)),
        ]),
      ),
    );
  }
}

class _WeekEventChip extends ConsumerWidget {
  const _WeekEventChip({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _eventColor(context, event);
    return Semantics(
      label:
          '${event.title}, ${DateFormat.jm().format(event.startAt)} to ${DateFormat.jm().format(event.endAt)}',
      button: true,
      child: InkWell(
        onTap: () => _showEventDetails(context, ref, event),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              border: Border(left: BorderSide(color: color, width: 3)),
              borderRadius: BorderRadius.circular(8)),
          child: Text(event.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _DateNavigator extends ConsumerWidget {
  const _DateNavigator({required this.state});
  final CalendarState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    return Row(children: [
      IconButton(
          tooltip: 'Previous day',
          onPressed: () => controller
              .selectDate(state.selectedDate.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left_rounded)),
      Expanded(
          child: Center(
              child: Text(DateFormat.yMMMMEEEEd().format(state.selectedDate),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)))),
      IconButton(
          tooltip: 'Next day',
          onPressed: () => controller
              .selectDate(state.selectedDate.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right_rounded))
    ]);
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.state});
  final CalendarState state;
  @override
  Widget build(BuildContext context) {
    final today = state.selectedDayEvents;
    final focusMinutes = today
        .where((event) =>
            event.eventType == 'focus_block' || event.eventType == 'deep_work')
        .fold<int>(0, (sum, event) => sum + event.duration.inMinutes);
    final scheduled =
        today.fold<int>(0, (sum, event) => sum + event.duration.inMinutes);
    return Card(
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.55),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded),
                const SizedBox(width: 8),
                Text('Time intelligence',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _Metric(label: 'Events', value: '${today.length}'),
                _Metric(label: 'Scheduled', value: '${scheduled}m'),
                _Metric(label: 'Focus', value: '${focusMinutes}m'),
                _Metric(label: 'Conflicts', value: '${state.conflicts.length}')
              ]),
              const SizedBox(height: 10),
              Text(
                  today.isEmpty
                      ? 'A clear day can become a focus day.'
                      : 'The next best action is shown in time order. Flexible events can move; locked events stay protected.',
                  style: Theme.of(context).textTheme.bodySmall)
            ])));
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

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});
  final CalendarEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final color = _eventColor(context, event);
    return Semantics(
      label:
          '${event.title}, ${DateFormat.jm().format(event.startAt)} to ${DateFormat.jm().format(event.endAt)}',
      button: true,
      child: Card(
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEventDetails(context, ref, event),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 4,
                    height: 68,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(8))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(event.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        decoration: event.completed
                                            ? TextDecoration.lineThrough
                                            : null))),
                        if (event.aiScheduled)
                          const Chip(
                              label: Text('AI'),
                              visualDensity: VisualDensity.compact)
                      ]),
                      const SizedBox(height: 5),
                      Text(
                          '${DateFormat.jm().format(event.startAt)} – ${DateFormat.jm().format(event.endAt)} · ${event.duration.inMinutes} min'),
                      const SizedBox(height: 7),
                      Wrap(spacing: 6, children: [
                        _SmallTag(text: event.category, color: color),
                        _SmallTag(text: event.priority),
                        _SmallTag(
                            text: event.energyLevel, icon: Icons.bolt_rounded),
                        if (event.location != null)
                          _SmallTag(
                              text: event.location!, icon: Icons.place_outlined)
                      ]),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(event.description,
                            maxLines: 2, overflow: TextOverflow.ellipsis)
                      ],
                    ],
                  ),
                ),
                Checkbox(
                    value: event.completed,
                    onChanged: (_) => controller.toggleCompleted(event)),
                PopupMenuButton<String>(
                    tooltip: 'Event actions',
                    onSelected: (action) => _eventAction(ref, event, action),
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'archive', child: Text('Archive')),
                          PopupMenuItem(
                              value: 'duplicate', child: Text('Duplicate')),
                          PopupMenuItem(value: 'delete', child: Text('Delete'))
                        ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.text, this.icon, this.color});
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

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.conflicts});
  final List<CalendarConflict> conflicts;
  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${conflicts.length} schedule conflict${conflicts.length == 1 ? '' : 's'}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(conflicts.first.suggestedResolution,
                      style: Theme.of(context).textTheme.bodySmall)
                ]))
          ])));
}

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar({required this.onCreate, required this.message});
  final VoidCallback onCreate;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Icon(Icons.event_available_rounded, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create event')),
            ],
          ),
        ),
      );
}

class _CalendarLoading extends StatelessWidget {
  const _CalendarLoading();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          5,
          (index) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 14),
                Expanded(
                    child: Container(
                        height: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest))
              ]),
            ),
          ),
        ),
      );
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
                'Calendar is offline-ready but could not load this copy.'),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('Retry'))
          ])));
}

DateTime _startOfWeek(DateTime date, {int firstDayOfWeek = 1}) {
  final normalized = DateTime(date.year, date.month, date.day);
  final distance = (normalized.weekday - firstDayOfWeek) % 7;
  return normalized.subtract(Duration(days: distance));
}

DateTime _roundToQuarter(DateTime value) {
  final rounded = ((value.minute + 14) ~/ 15) * 15;
  final base = DateTime(value.year, value.month, value.day, value.hour);
  return base.add(Duration(minutes: rounded));
}

Future<DateTime?> _pickScheduleDateTime(BuildContext context,
    {required DateTime initial}) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year, now.month, now.day);
  final initialDate = initial.isBefore(firstDate)
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
      context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _formatHour(int minute) {
  final hour = minute ~/ 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display $suffix';
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

Color _eventColor(BuildContext context, CalendarEvent event) =>
    switch (event.eventType) {
      'focus_block' || 'deep_work' => Colors.indigo,
      'meeting' => Colors.teal,
      'break' => Colors.green,
      'travel' => Colors.orange,
      _ => Theme.of(context).colorScheme.primary
    };

Future<void> _showEventEditor(BuildContext context, WidgetRef ref,
    {String? projectId, DateTime? initialDate}) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final location = TextEditingController();
  var eventType = 'task_block';
  var priority = 'medium';
  var energy = 'medium';
  var canCreate = false;
  var scheduledStart = _roundToQuarter(initialDate == null
      ? DateTime.now().add(const Duration(minutes: 30))
      : DateTime(initialDate.year, initialDate.month, initialDate.day,
          DateTime.now().hour, DateTime.now().minute));

  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('New calendar event'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  onChanged: (value) =>
                      setState(() => canCreate = value.trim().isNotEmpty),
                  decoration: const InputDecoration(
                      labelText: 'What should happen?',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Context or notes',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: eventType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          'task_block',
                          'focus_block',
                          'meeting',
                          'break',
                          'study',
                          'exercise',
                          'travel'
                        ]
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => eventType = value ?? eventType),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration:
                            const InputDecoration(labelText: 'Priority'),
                        items: const ['critical', 'high', 'medium', 'low']
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => priority = value ?? priority),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickScheduleDateTime(context,
                        initial: scheduledStart);
                    if (picked != null) setState(() => scheduledStart = picked);
                  },
                  icon: const Icon(Icons.event_available_outlined),
                  label:
                      Text(DateFormat.yMMMd().add_jm().format(scheduledStart)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: energy,
                  decoration:
                      const InputDecoration(labelText: 'Energy required'),
                  items: const [
                    'very_low',
                    'low',
                    'medium',
                    'high',
                    'deep_work'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => energy = value ?? energy),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: location,
                    decoration: const InputDecoration(
                        labelText: 'Location (optional)',
                        border: OutlineInputBorder())),
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

  if (created == true && title.text.trim().isNotEmpty) {
    await ref.read(calendarControllerProvider.notifier).createEvent(
        title: title.text,
        description: description.text,
        location: location.text.isEmpty ? null : location.text,
        startAt: scheduledStart,
        endAt: scheduledStart.add(const Duration(minutes: 50)),
        eventType: eventType,
        priority: priority,
        energyLevel: energy,
        projectId: projectId);
  }
  title.dispose();
  description.dispose();
  location.dispose();
}

Future<void> _showEventDetails(
    BuildContext context, WidgetRef ref, CalendarEvent event) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(event.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${DateFormat.yMMMd().add_jm().format(event.startAt)} – ${DateFormat.jm().format(event.endAt)}'),
            const SizedBox(height: 12),
            Text(event.description.isEmpty
                ? 'No description'
                : event.description),
            if (event.location != null) ...[
              const SizedBox(height: 12),
              Text('Location: ${event.location}')
            ],
            const SizedBox(height: 12),
            Text(
                event.locked
                    ? 'Locked event: moving is protected.'
                    : 'Flexible event: the scheduler may suggest another slot.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close')),
        FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(calendarControllerProvider.notifier)
                  .toggleCompleted(event);
            },
            child: Text(event.completed ? 'Reopen' : 'Complete')),
      ],
    ),
  );
}

void _eventAction(WidgetRef ref, CalendarEvent event, String action) {
  final controller = ref.read(calendarControllerProvider.notifier);
  switch (action) {
    case 'archive':
      controller.archive(event);
    case 'duplicate':
      controller.createEvent(
          title: '${event.title} (copy)',
          description: event.description,
          startAt: event.startAt.add(const Duration(days: 1)),
          endAt: event.endAt.add(const Duration(days: 1)),
          eventType: event.eventType,
          priority: event.priority,
          energyLevel: event.energyLevel);
    case 'delete':
      controller.deleteEvent(event);
  }
}

Future<void> _showPreferences(BuildContext context, WidgetRef ref) async {
  final current = ref.read(calendarControllerProvider).valueOrNull;
  if (current == null) return;
  var reducedMotion = current.preferences.reducedMotion;
  var highContrast = current.preferences.highContrast;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Calendar preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
                title: const Text('Reduce motion'),
                subtitle: const Text('Keep transitions calm and minimal'),
                value: reducedMotion,
                onChanged: (value) => setState(() => reducedMotion = value)),
            SwitchListTile(
                title: const Text('High contrast'),
                subtitle: const Text('Increase visual separation'),
                value: highContrast,
                onChanged: (value) => setState(() => highContrast = value)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save')),
        ],
      ),
    ),
  );
  if (saved == true) {
    await ref.read(calendarControllerProvider.notifier).updatePreferences(
        current.preferences.copyWith(
            reducedMotion: reducedMotion, highContrast: highContrast));
  }
}
