import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/search_repository.dart';
import 'search_models.dart';

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, SearchState>(SearchController.new);

class SearchController extends AsyncNotifier<SearchState> {
  SearchRepository? _repository;

  @override
  Future<SearchState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = SearchRepository(preferences);
    final filters = const SearchFiltersModel();
    return SearchState(
      results: const [],
      history: await _repository!.loadHistory(),
      savedSearches: await _repository!.loadSavedSearches(),
      collections: await _repository!.smartCollections(filters: filters),
      commands: _commands(),
      query: '',
      filters: filters,
    );
  }

  Future<void> searchNow({String? query, String? searchType}) async {
    final current = state.valueOrNull;
    if (_repository == null || current == null) return;
    final nextQuery = query ?? current.query;
    final nextType = searchType ?? current.searchType;
    final results =
        await _repository!.search(nextQuery, filters: current.filters);
    state = AsyncData(current.copyWith(
      query: nextQuery,
      searchType: nextType,
      results: results,
      history: await _repository!.loadHistory(),
      collections:
          await _repository!.smartCollections(filters: current.filters),
      clearSelectedResult: true,
    ));
  }

  void setQuery(String query) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(query: query));
  }

  Future<void> setFilters(SearchFiltersModel filters) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(filters: filters));
    await searchNow();
  }

  void selectResult(SearchResultModel? result) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
          selectedResult: result, clearSelectedResult: result == null));
    }
  }

  Future<void> saveCurrentSearch(
      {required String name, bool favorite = false}) async {
    final current = state.valueOrNull;
    if (_repository == null ||
        current == null ||
        current.query.trim().isEmpty) {
      return;
    }
    await _repository!.saveSearch(SavedSearchModel(
        name: name,
        query: current.query,
        filters: current.filters,
        favorite: favorite));
    state = AsyncData(current.copyWith(
        savedSearches: await _repository!.loadSavedSearches()));
  }

  Future<void> runStudy(
      {required SearchResultModel source,
      required String text,
      String resourceType = 'executive_summary'}) async {
    if (_repository == null) {
      return;
    }
    final resource = await _repository!.study(
        sourceId: source.documentId,
        title: source.title,
        text: text.isEmpty ? source.preview : text,
        resourceType: resourceType);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(studyResource: resource));
    }
  }

  Future<void> discover(SearchResultModel source) async {
    if (_repository == null) {
      return;
    }
    final result = await _repository!.discovery(source);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(discovery: result));
    }
  }

  Future<void> refreshCommands(String query) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final commands = _commands().where((command) {
      if (query.trim().isEmpty) return true;
      final text = [
        command.title,
        command.subtitle,
        command.category,
        ...command.keywords
      ].join(' ').toLowerCase();
      return text.contains(query.toLowerCase());
    }).toList();
    state = AsyncData(current.copyWith(commands: commands));
  }

  List<CommandItemModel> _commands() => const [
        CommandItemModel(
            id: 'navigate.dashboard',
            title: 'Open Dashboard',
            subtitle: 'FocusFlow command center',
            category: 'Navigate',
            action: 'navigate',
            route: '/',
            icon: 'dashboard'),
        CommandItemModel(
            id: 'navigate.tasks',
            title: 'Open Tasks',
            subtitle: 'Smart task management',
            category: 'Navigate',
            action: 'navigate',
            route: '/tasks',
            keywords: ['todo', 'work'],
            icon: 'checklist'),
        CommandItemModel(
            id: 'navigate.calendar',
            title: 'Open Calendar',
            subtitle: 'Time intelligence',
            category: 'Navigate',
            action: 'navigate',
            route: '/calendar',
            icon: 'calendar'),
        CommandItemModel(
            id: 'navigate.notes',
            title: 'Open Notes',
            subtitle: 'Second Brain',
            category: 'Navigate',
            action: 'navigate',
            route: '/notes',
            keywords: ['knowledge'],
            icon: 'notes'),
        CommandItemModel(
            id: 'navigate.projects',
            title: 'Open Projects',
            subtitle: 'Workspaces and goals',
            category: 'Navigate',
            action: 'navigate',
            route: '/organization',
            keywords: ['goals', 'workspace'],
            icon: 'folder'),
        CommandItemModel(
            id: 'navigate.assets',
            title: 'Open Assets',
            subtitle: 'Knowledge storage',
            category: 'Navigate',
            action: 'navigate',
            route: '/assets',
            keywords: ['files', 'pdf'],
            icon: 'asset'),
        CommandItemModel(
            id: 'navigate.graph',
            title: 'Open Knowledge Explorer',
            subtitle: 'Relationships and backlinks',
            category: 'Navigate',
            action: 'navigate',
            route: '/knowledge-graph',
            keywords: ['graph', 'relationships'],
            icon: 'hub'),
        CommandItemModel(
            id: 'navigate.reminders',
            title: 'Open Reminder Center',
            subtitle: 'Notifications and follow-ups',
            category: 'Navigate',
            action: 'navigate',
            route: '/reminders',
            keywords: ['alerts'],
            icon: 'notifications'),
        CommandItemModel(
            id: 'create.task',
            title: 'Create Task',
            subtitle: 'Add a new task',
            category: 'Create',
            action: 'create_task',
            keywords: ['todo'],
            icon: 'add_task'),
        CommandItemModel(
            id: 'create.note',
            title: 'Create Note',
            subtitle: 'Capture knowledge',
            category: 'Create',
            action: 'create_note',
            keywords: ['write'],
            icon: 'note_add'),
        CommandItemModel(
            id: 'focus.start',
            title: 'Start Focus Session',
            subtitle: 'Begin a distraction-free block',
            category: 'Execute',
            action: 'start_focus',
            keywords: ['timer', 'deep work'],
            icon: 'timer'),
        CommandItemModel(
            id: 'assistant.open',
            title: 'Open AI Assistant',
            subtitle: 'Ask FocusFlow for help',
            category: 'Execute',
            action: 'navigate',
            route: '/assistant',
            keywords: ['chat', 'ask'],
            icon: 'assistant'),
      ];
}
