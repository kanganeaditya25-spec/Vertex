import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/search/search_models.dart';
import '../lib/repositories/search_repository.dart';

void main() {
  late SearchRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SearchRepository(await SharedPreferences.getInstance());
  });

  SearchResultModel document({required String id, required String title, required String workspace, required String type, List<String> tags = const []}) => SearchResultModel(
        documentId: id,
        title: title,
        score: 0,
        snippet: '$title contains useful productivity knowledge',
        preview: '$title contains useful productivity knowledge',
        sourceType: type,
        metadata: {'workspace_id': workspace, 'tags': tags},
      );

  test('searches offline with source and tag filters while preserving workspace isolation', () async {
    await repository.indexDocument(document(id: 'a-project', title: 'React Dashboard', workspace: 'workspace-a', type: 'project', tags: ['react', 'frontend']));
    await repository.indexDocument(document(id: 'a-note', title: 'React Notes', workspace: 'workspace-a', type: 'note', tags: ['react']));
    await repository.indexDocument(document(id: 'b-project', title: 'React Dashboard Other', workspace: 'workspace-b', type: 'project', tags: ['react']));

    final results = await repository.search('React', filters: const SearchFiltersModel(workspaceId: 'workspace-a', sourceTypes: ['project'], tags: ['frontend']));

    expect(results.map((result) => result.documentId), ['a-project']);
  });

  test('records search history and persists saved searches', () async {
    await repository.indexDocument(document(id: 'task-1', title: 'Plan sprint', workspace: 'workspace-a', type: 'task'));
    await repository.search('Plan', filters: const SearchFiltersModel(workspaceId: 'workspace-a'));
    await repository.saveSearch(const SavedSearchModel(name: 'Sprint work', query: 'Plan', favorite: true));

    final history = await repository.loadHistory();
    final saved = await SearchRepository(await SharedPreferences.getInstance()).loadSavedSearches();

    expect(history.single.query, 'Plan');
    expect(history.single.resultCount, 1);
    expect(saved.single.name, 'Sprint work');
    expect(saved.single.favorite, isTrue);
  });

  test('extracts deterministic study resources with concepts, definitions, formulas, dates, and questions', () async {
    final resource = await repository.study(
      sourceId: 'source-1',
      title: 'Operating Systems',
      text: 'Process is a program in execution. Threads are lightweight execution units.\nT = 4\nReview in 2026.',
      resourceType: 'cheat_sheet',
    );

    expect(resource.content['summary'], contains('Process is a program'));
    expect(resource.content['definitions'], isNotEmpty);
    expect(resource.content['formulas'], contains('T = 4'));
    expect(resource.content['important_dates'], contains('2026'));
    expect(resource.content['important_questions'], isNotEmpty);
  });

  test('builds smart collections and discovery from indexed local knowledge', () async {
    final first = document(id: 'note-1', title: 'Focus planning', workspace: 'workspace-a', type: 'note', tags: ['focus']);
    final second = document(id: 'note-2', title: 'Focus review', workspace: 'workspace-a', type: 'note', tags: ['focus']);
    await repository.indexDocument(first);
    await repository.indexDocument(second);
    await repository.indexDocument(document(id: 'task-1', title: 'Plan focus block', workspace: 'workspace-a', type: 'task', tags: ['focus']));

    final collections = await repository.smartCollections(filters: const SearchFiltersModel(workspaceId: 'workspace-a'));
    final discovery = await repository.discovery(first);

    expect(collections.any((collection) => collection.itemIds.length >= 2), isTrue);
    expect(discovery.relatedResults.map((result) => result.documentId), contains('note-2'));
    expect(discovery.recommendedCollections, isNotEmpty);
  });
}
