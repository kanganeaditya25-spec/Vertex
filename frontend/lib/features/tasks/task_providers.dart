import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/task_repository.dart';
import 'task_models.dart';

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, TaskState>(TaskController.new);

class TaskState {
  const TaskState(
      {required this.tasks,
      this.query = '',
      this.statusFilter,
      this.priorityFilter,
      this.sortBy = 'priority',
      this.selectedIds = const {}});

  final List<TaskModel> tasks;
  final String query;
  final String? statusFilter;
  final String? priorityFilter;
  final String sortBy;
  final Set<String> selectedIds;

  List<TaskModel> get visibleTasks {
    final normalized = query.trim().toLowerCase();
    final filtered = tasks.where((task) {
      final matchesQuery = normalized.isEmpty ||
          task.title.toLowerCase().contains(normalized) ||
          task.description.toLowerCase().contains(normalized) ||
          task.tags.any((tag) => tag.contains(normalized));
      final matchesStatus = statusFilter == null || task.status == statusFilter;
      final matchesPriority =
          priorityFilter == null || task.priority == priorityFilter;
      return matchesQuery &&
          matchesStatus &&
          matchesPriority &&
          !task.isDeleted;
    }).toList();
    filtered.sort((a, b) {
      if (sortBy == 'deadline') {
        return (a.deadline ?? DateTime(9999))
            .compareTo(b.deadline ?? DateTime(9999));
      }
      if (sortBy == 'created') {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (sortBy == 'title') {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return b.aiScore.compareTo(a.aiScore);
    });
    return filtered;
  }

  int get completedCount => tasks.where((task) => task.isCompleted).length;
  int get remainingCount =>
      tasks.where((task) => !task.isCompleted && !task.isArchived).length;
  int get urgentCount => tasks
      .where((task) => task.priority == 'critical' || task.priority == 'urgent')
      .length;

  TaskState copyWith(
          {List<TaskModel>? tasks,
          String? query,
          String? statusFilter,
          String? priorityFilter,
          String? sortBy,
          Set<String>? selectedIds,
          bool clearStatus = false,
          bool clearPriority = false}) =>
      TaskState(
        tasks: tasks ?? this.tasks,
        query: query ?? this.query,
        statusFilter: clearStatus ? null : statusFilter ?? this.statusFilter,
        priorityFilter:
            clearPriority ? null : priorityFilter ?? this.priorityFilter,
        sortBy: sortBy ?? this.sortBy,
        selectedIds: selectedIds ?? this.selectedIds,
      );
}

class TaskController extends AsyncNotifier<TaskState> {
  TaskRepository? _repository;

  @override
  Future<TaskState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = TaskRepository(preferences);
    return TaskState(tasks: await _repository!.loadTasks());
  }

  Future<void> setQuery(String query) async =>
      _setState((current) => current.copyWith(query: query));
  Future<void> setStatusFilter(String? filter) async =>
      _setState((current) => filter == null
          ? current.copyWith(clearStatus: true)
          : current.copyWith(statusFilter: filter));
  Future<void> setPriorityFilter(String? filter) async =>
      _setState((current) => filter == null
          ? current.copyWith(clearPriority: true)
          : current.copyWith(priorityFilter: filter));
  Future<void> setSort(String sort) async =>
      _setState((current) => current.copyWith(sortBy: sort));

  Future<void> createTask(
      {required String title,
      String description = '',
      String priority = 'medium',
      String category = 'general',
      DateTime? deadline,
      int estimatedMinutes = 0,
      List<String> tags = const []}) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final now = DateTime.now();
    final task = TaskModel(
        id: 'local-${now.microsecondsSinceEpoch}',
        title: title.trim(),
        description: description.trim(),
        priority: priority,
        category: category,
        deadline: deadline,
        estimatedMinutes: estimatedMinutes,
        tags: tags,
        createdAt: now,
        updatedAt: now);
    final saved = await _repository!.create(task);
    state = AsyncData(current.copyWith(tasks: [...current.tasks, saved]));
  }

  Future<void> updateTask(TaskModel task) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final saved = await _repository!.update(task);
    state = AsyncData(current.copyWith(
        tasks: current.tasks
            .map((item) => item.id == saved.id ? saved : item)
            .toList()));
  }

  Future<void> toggleComplete(TaskModel task) async {
    final status = task.isCompleted ? 'inbox' : 'completed';
    await updateTask(task.copyWith(
        status: status,
        completionPercent: status == 'completed' ? 100 : 0,
        completedAt: status == 'completed' ? DateTime.now() : null,
        clearCompletedAt: status != 'completed'));
  }

  Future<void> archive(TaskModel task) async =>
      updateTask(task.copyWith(status: 'archived', archivedAt: DateTime.now()));
  Future<void> restore(TaskModel task) async => updateTask(task.copyWith(
      status: 'inbox', clearArchivedAt: true, clearDeletedAt: true));

  Future<void> deleteTask(TaskModel task) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    await _repository!.remove(task);
    state = AsyncData(current.copyWith(
        tasks: current.tasks.where((item) => item.id != task.id).toList()));
  }

  Future<void> duplicate(TaskModel task) async {
    final current = state.valueOrNull;
    if (current == null || _repository == null) return;
    final now = DateTime.now();
    final duplicate = await _repository!.create(task.copyWith(
        title: '${task.title} (copy)',
        status: 'inbox',
        pinned: false,
        favorite: false,
        createdAt: now,
        updatedAt: now));
    state = AsyncData(current.copyWith(tasks: [...current.tasks, duplicate]));
  }

  Future<void> togglePin(TaskModel task) async =>
      updateTask(task.copyWith(pinned: !task.pinned));
  Future<void> toggleFavorite(TaskModel task) async =>
      updateTask(task.copyWith(favorite: !task.favorite));

  Future<void> toggleSelection(String taskId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final selected = {...current.selectedIds};
    selected.contains(taskId) ? selected.remove(taskId) : selected.add(taskId);
    state = AsyncData(current.copyWith(selectedIds: selected));
  }

  Future<void> clearSelection() async {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(selectedIds: {}));
  }

  Future<void> bulkComplete() async {
    final current = state.valueOrNull;
    if (current == null) return;
    for (final task in current.tasks
        .where((item) => current.selectedIds.contains(item.id))) {
      await updateTask(task.copyWith(
          status: 'completed',
          completionPercent: 100,
          completedAt: DateTime.now()));
    }
    await clearSelection();
  }

  Future<void> _setState(TaskState Function(TaskState) transform) async {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(transform(current));
  }
}
