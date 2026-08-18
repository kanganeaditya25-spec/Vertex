import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/calendar_repository.dart';
import 'calendar_models.dart';

final calendarControllerProvider =
    AsyncNotifierProvider<CalendarController, CalendarState>(
        CalendarController.new);

class CalendarState {
  const CalendarState(
      {required this.events,
      required this.selectedDate,
      required this.preferences,
      this.view = 'agenda',
      this.query = '',
      this.categoryFilter,
      this.conflicts = const []});

  final List<CalendarEvent> events;
  final DateTime selectedDate;
  final CalendarPreferences preferences;
  final String view;
  final String query;
  final String? categoryFilter;
  final List<CalendarConflict> conflicts;

  List<CalendarEvent> get visibleEvents {
    final normalized = query.trim().toLowerCase();
    return events.where((event) {
      final searchable =
          '${event.title} ${event.description} ${event.location ?? ''} ${event.category}'
              .toLowerCase();
      final matchesQuery =
          normalized.isEmpty || searchable.contains(normalized);
      final matchesCategory =
          categoryFilter == null || event.category == categoryFilter;
      return matchesQuery &&
          matchesCategory &&
          event.status != 'deleted' &&
          event.status != 'archived';
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<CalendarEvent> get selectedDayEvents => visibleEvents
      .where((event) =>
          _sameDate(event.startAt, selectedDate) ||
          _sameDate(event.endAt, selectedDate) ||
          (event.startAt.isBefore(selectedDate) &&
              event.endAt.isAfter(DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day))))
      .toList();
  List<CalendarEvent> get upcomingEvents => visibleEvents
      .where((event) => event.endAt.isAfter(DateTime.now()))
      .take(5)
      .toList();

  CalendarState copyWith(
          {List<CalendarEvent>? events,
          DateTime? selectedDate,
          CalendarPreferences? preferences,
          String? view,
          String? query,
          String? categoryFilter,
          List<CalendarConflict>? conflicts,
          bool clearCategory = false}) =>
      CalendarState(
          events: events ?? this.events,
          selectedDate: selectedDate ?? this.selectedDate,
          preferences: preferences ?? this.preferences,
          view: view ?? this.view,
          query: query ?? this.query,
          categoryFilter:
              clearCategory ? null : categoryFilter ?? this.categoryFilter,
          conflicts: conflicts ?? this.conflicts);
}

class CalendarController extends AsyncNotifier<CalendarState> {
  CalendarRepository? _repository;

  @override
  Future<CalendarState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = CalendarRepository(preferences);
    final savedPreferences = await _repository!.loadPreferences();
    final events = await _repository!.loadEvents();
    final now = DateTime.now();
    return CalendarState(
        events: events,
        selectedDate: DateTime(now.year, now.month, now.day),
        preferences: savedPreferences,
        view: savedPreferences.defaultView);
  }

  Future<void> selectDate(DateTime date) async => _update((state) =>
      state.copyWith(selectedDate: DateTime(date.year, date.month, date.day)));
  Future<void> setView(String view) async => _update((state) => state.copyWith(
      view: view, preferences: state.preferences.copyWith(defaultView: view))
    ..persistPreferences(_repository));
  Future<void> setQuery(String query) async =>
      _update((state) => state.copyWith(query: query));
  Future<void> setCategory(String? category) async =>
      _update((state) => category == null
          ? state.copyWith(clearCategory: true)
          : state.copyWith(categoryFilter: category));

  Future<void> createEvent(
      {required String title,
      required DateTime startAt,
      required DateTime endAt,
      String eventType = 'custom',
      String category = 'general',
      String priority = 'medium',
      String description = '',
      String? location,
      int estimatedMinutes = 0,
      String energyLevel = 'medium',
      bool flexible = true}) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final now = DateTime.now();
    final event = CalendarEvent(
        id: 'local-${now.microsecondsSinceEpoch}',
        title: title.trim(),
        description: description.trim(),
        startAt: startAt,
        endAt: endAt,
        eventType: eventType,
        category: category,
        priority: priority,
        location: location,
        estimatedMinutes: estimatedMinutes,
        energyLevel: energyLevel,
        flexible: flexible,
        createdAt: now,
        updatedAt: now);
    final saved = await _repository!.create(event);
    await _replace([...current.events, saved]);
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null || event.locked) return;
    final saved = await _repository!.update(event);
    await _replace(current.events
        .map((item) => item.id == saved.id ? saved : item)
        .toList());
  }

  Future<void> moveEvent(CalendarEvent event, DateTime newStart) async {
    if (event.locked) return;
    await updateEvent(
        event.copyWith(startAt: newStart, endAt: newStart.add(event.duration)));
  }

  Future<void> toggleCompleted(CalendarEvent event) async =>
      updateEvent(event.copyWith(
          completed: !event.completed,
          status: event.completed ? 'scheduled' : 'completed'));
  Future<void> archive(CalendarEvent event) async =>
      updateEvent(event.copyWith(status: 'archived'));

  Future<void> deleteEvent(CalendarEvent event) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    await _repository!.remove(event);
    await _replace(
        current.events.where((item) => item.id != event.id).toList());
  }

  Future<void> updatePreferences(CalendarPreferences preferences) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    await _repository!.savePreferences(preferences);
    state = AsyncData(current.copyWith(preferences: preferences));
  }

  Future<void> recalculateConflicts() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final events = current.visibleEvents;
    final conflicts = <CalendarConflict>[];
    for (var index = 0; index < events.length; index++) {
      for (final other in events.skip(index + 1)) {
        if (events[index].endAt.isAfter(other.startAt) &&
            other.endAt.isAfter(events[index].startAt)) {
          conflicts.add(CalendarConflict(
              conflictType: 'overlap',
              severity:
                  events[index].locked || other.locked ? 'high' : 'moderate',
              eventIds: [events[index].id, other.id],
              message: '${events[index].title} overlaps ${other.title}.',
              suggestedResolution: events[index].locked || other.locked
                  ? 'Keep the locked event and move the flexible event.'
                  : 'Move the lower-priority event to the next free slot.'));
        }
      }
    }
    state = AsyncData(current.copyWith(conflicts: conflicts));
  }

  Future<void> _replace(List<CalendarEvent> events) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(events: events));
    await recalculateConflicts();
  }

  Future<void> _update(CalendarState Function(CalendarState) update) async {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(update(current));
  }
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

extension on CalendarState {
  CalendarState persistPreferences(CalendarRepository? repository) {
    if (repository != null) repository.savePreferences(preferences);
    return this;
  }
}
