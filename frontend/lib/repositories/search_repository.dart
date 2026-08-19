import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/knowledge_graph/graph_models.dart';
import '../features/search/search_models.dart';

class SearchRepository {
  SearchRepository(this.preferences);

  final SharedPreferences preferences;
  static const _documentsKey = 'global_search_documents_v1';
  static const _historyKey = 'global_search_history_v1';
  static const _savedKey = 'global_search_saved_v1';

  Future<List<SearchResultModel>> search(String query,
      {SearchFiltersModel filters = const SearchFiltersModel()}) async {
    final documents = await _loadDocuments();
    final graphNodes = await _loadGraphNodes();
    final byId = <String, SearchResultModel>{
      for (final result in [...documents, ...graphNodes])
        result.documentId: result,
    };
    final normalized = _normalizeQuery(query);
    final tokens = _tokens(normalized);
    final scored = <({double score, SearchResultModel result})>[];
    for (final result in byId.values) {
      if (!_matchesFilters(result, filters)) continue;
      final text = [
        result.title,
        result.snippet,
        result.preview,
        result.sourceType,
        ..._stringList(result.metadata['tags'])
      ].join(' ').toLowerCase();
      final textTokens = _tokens(text);
      final matched = tokens.intersection(textTokens).length;
      final fuzzy =
          SequenceMatcher.similarity(normalized, result.title.toLowerCase());
      if (matched == 0 && fuzzy < 0.42) {
        continue;
      }
      var score = tokens.isEmpty ? 0.1 : matched / tokens.length;
      if (normalized.isNotEmpty &&
          result.title.toLowerCase().contains(normalized)) {
        score += 1;
      }
      score += fuzzy * 0.2;
      scored.add((score: score, result: result));
    }
    scored.sort((left, right) => right.score.compareTo(left.score));
    final results = scored.take(100).map((item) => item.result).toList();
    await _recordHistory(query, results.length);
    return results;
  }

  Future<void> indexDocument(SearchResultModel document) async {
    final documents = await _loadDocuments();
    final index =
        documents.indexWhere((item) => item.documentId == document.documentId);
    if (index < 0) {
      documents.add(document);
    } else {
      documents[index] = document;
    }
    await _saveDocuments(documents);
  }

  Future<List<SearchHistoryModel>> loadHistory() async {
    final raw = preferences.getString(_historyKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return SearchHistoryModel(
            query: '${map['query'] ?? ''}',
            resultCount: map['result_count'] as int? ?? 0,
            createdAt:
                DateTime.tryParse('${map['created_at']}') ?? DateTime.now());
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SavedSearchModel>> loadSavedSearches() async {
    final raw = preferences.getString(_savedKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final filters = Map<String, dynamic>.from(map['filters'] ?? const {});
        return SavedSearchModel(
            name: '${map['name'] ?? ''}',
            query: '${map['query'] ?? ''}',
            favorite: map['favorite'] as bool? ?? false,
            filters: SearchFiltersModel(
                workspaceId: '${filters['workspace_id'] ?? ''}',
                projectId: '${filters['project_id'] ?? ''}',
                category: '${filters['category'] ?? ''}',
                tags: _stringList(filters['tags']),
                sourceTypes: _stringList(filters['source_types']),
                recentOnly: filters['recent_only'] as bool? ?? false));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSearch(SavedSearchModel search) async {
    final saved = await loadSavedSearches();
    final index = saved.indexWhere((item) => item.name == search.name);
    if (index < 0) {
      saved.add(search);
    } else {
      saved[index] = search;
    }
    await preferences.setString(
        _savedKey,
        jsonEncode(saved
            .map((item) => {
                  'name': item.name,
                  'query': item.query,
                  'favorite': item.favorite,
                  'filters': item.filters.toJson()
                })
            .toList()));
  }

  Future<List<SmartCollectionModel>> smartCollections(
      {SearchFiltersModel filters = const SearchFiltersModel()}) async {
    final results = await _loadDocuments() + await _loadGraphNodes();
    final groups = <String, List<String>>{};
    for (final result in results) {
      if (!_matchesFilters(result, filters)) continue;
      groups.putIfAbsent(result.sourceType, () => []).add(result.documentId);
    }
    return [
      for (final entry
          in groups.entries.where((entry) => entry.value.length >= 2))
        SmartCollectionModel(
            name: 'Related ${entry.key.replaceAll('_', ' ').toUpperCase()}',
            description: 'Automatically grouped offline by source type.',
            itemIds: entry.value.toSet().toList(),
            aiRecommended: true),
    ];
  }

  Future<StudyResourceModel> study(
      {required String sourceId,
      required String title,
      required String text,
      String resourceType = 'executive_summary'}) async {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final words = RegExp(r'[A-Za-z][A-Za-z0-9_-]{2,}')
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .where((word) => !{'the', 'and', 'for', 'with', 'from', 'this', 'that'}
            .contains(word))
        .toList();
    final counts = <String, int>{};
    for (final word in words) {
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final concepts = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final definitions = RegExp(
            r'([A-Z][A-Za-z0-9 _-]{2,40})\s+(?:is|means|refers to)\s+([^.!?]{10,180})')
        .allMatches(text)
        .map((match) => {'term': match.group(1), 'definition': match.group(2)})
        .toList();
    return StudyResourceModel(
        sourceId: sourceId,
        title: title,
        resourceType: resourceType,
        content: {
          'summary': sentences.take(3).join(' '),
          'detailed_summary': sentences.take(12).join(' '),
          'key_concepts': concepts.take(12).map((entry) => entry.key).toList(),
          'definitions': definitions,
          'formulas': text
              .split('\n')
              .where((line) => line.contains('='))
              .take(12)
              .toList(),
          'important_dates': RegExp(r'\b(?:19|20)\d{2}\b')
              .allMatches(text)
              .map((match) => match.group(0))
              .toList(),
          'revision_notes': sentences.take(15).toList(),
          'cheat_sheet': concepts.take(10).map((entry) => entry.key).toList(),
          'important_questions': concepts
              .take(8)
              .map((entry) => 'How does ${entry.key} work?')
              .toList()
        });
  }

  Future<DiscoveryModel> discovery(SearchResultModel source) async {
    final all = await _loadDocuments() + await _loadGraphNodes();
    final sourceTokens =
        _tokens([source.title, source.snippet, source.preview].join(' '));
    final related = all
        .where((item) => item.documentId != source.documentId)
        .map((item) => (
              score: _jaccard(sourceTokens,
                  _tokens([item.title, item.snippet, item.preview].join(' '))),
              result: item
            ))
        .where((item) => item.score > 0.08)
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    return DiscoveryModel(
        sourceId: source.documentId,
        relatedResults: related.take(12).map((item) => item.result).toList(),
        relatedNodeIds: const [],
        forgottenItems:
            related.reversed.take(5).map((item) => item.result).toList(),
        missingLinks: const [],
        recommendedCollections: [
          'Related ${source.sourceType.replaceAll('_', ' ')}',
          if (related.length > 1) 'Similar topics'
        ]);
  }

  Future<List<SearchResultModel>> _loadDocuments() async =>
      _readResults(_documentsKey);

  Future<List<SearchResultModel>> _loadGraphNodes() async {
    final raw = preferences.getString('knowledge_graph_nodes_v1');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((item) {
        final node =
            GraphNodeModel.fromJson(Map<String, dynamic>.from(item as Map));
        return SearchResultModel(
            documentId: node.id,
            title: node.label,
            score: 0,
            snippet: node.contentText,
            preview: node.contentText,
            sourceType: node.entityType,
            metadata: {
              ...node.metadata,
              'workspace_id': node.workspaceId,
              'tags': node.tags,
              'updated_at': node.updatedAt.toIso8601String()
            },
            quickActions: const [
              'open',
              'create_task',
              'create_reminder'
            ]);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SearchResultModel>> _readResults(String key) async {
    final raw = preferences.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => SearchResultModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveDocuments(List<SearchResultModel> documents) async =>
      preferences.setString(
          _documentsKey,
          jsonEncode(documents
              .map((item) => {
                    'document_id': item.documentId,
                    'title': item.title,
                    'score': item.score,
                    'snippet': item.snippet,
                    'source_type': item.sourceType,
                    'source_url': item.sourceUrl,
                    'metadata': item.metadata,
                    'preview': item.preview,
                    'thumbnail_url': item.thumbnailUrl,
                    'summary': item.summary,
                    'related_item_ids': item.relatedItemIds,
                    'ai_insights': item.aiInsights,
                    'quick_actions': item.quickActions
                  })
              .toList()));

  Future<void> _recordHistory(String query, int count) async {
    if (query.trim().isEmpty) return;
    final history = await loadHistory();
    history.insert(
        0,
        SearchHistoryModel(
            query: query, resultCount: count, createdAt: DateTime.now()));
    final trimmed = history
        .take(30)
        .map((item) => {
              'query': item.query,
              'result_count': item.resultCount,
              'created_at': item.createdAt.toIso8601String()
            })
        .toList();
    await preferences.setString(_historyKey, jsonEncode(trimmed));
  }

  String _normalizeQuery(String query) => query
      .toLowerCase()
      .replaceAll(
          RegExp(
              r'\b(show|find|all|where did i store|what am i working on|please)\b'),
          ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  Set<String> _tokens(String text) => RegExp(r'[A-Za-z0-9_]{2,}')
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => !{'the', 'and', 'for', 'with', 'from', 'this', 'that'}
          .contains(token))
      .toSet();
  double _jaccard(Set<String> left, Set<String> right) =>
      left.isEmpty || right.isEmpty
          ? 0
          : left.intersection(right).length / left.union(right).length;
  List<String> _stringList(dynamic value) =>
      value is List ? value.map((item) => '$item').toList() : const [];

  bool _matchesFilters(SearchResultModel result, SearchFiltersModel filters) {
    final workspace = '${result.metadata['workspace_id'] ?? ''}';
    if (filters.workspaceId.isNotEmpty &&
        workspace.isNotEmpty &&
        workspace != filters.workspaceId) {
      return false;
    }
    if (filters.projectId.isNotEmpty &&
        '${result.metadata['project_id'] ?? ''}' != filters.projectId) {
      return false;
    }
    if (filters.sourceTypes.isNotEmpty &&
        !filters.sourceTypes.contains(result.sourceType)) {
      return false;
    }
    if (filters.favorite != null &&
        (result.metadata['favorite'] as bool? ?? false) != filters.favorite) {
      return false;
    }
    if (filters.aiGenerated != null &&
        (result.metadata['ai_generated'] as bool? ?? false) !=
            filters.aiGenerated) {
      return false;
    }
    final tags = _stringList(result.metadata['tags'])
        .map((tag) => tag.toLowerCase())
        .toSet();
    if (filters.tags.any((tag) => !tags.contains(tag.toLowerCase()))) {
      return false;
    }
    return true;
  }
}

class SequenceMatcher {
  static double similarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final matrix =
        List.generate(left.length + 1, (_) => List.filled(right.length + 1, 0));
    for (var i = 1; i <= left.length; i++) {
      for (var j = 1; j <= right.length; j++) {
        matrix[i][j] = left[i - 1] == right[j - 1]
            ? matrix[i - 1][j - 1] + 1
            : max(matrix[i - 1][j], matrix[i][j - 1]);
      }
    }
    return matrix[left.length][right.length] / max(left.length, right.length);
  }
}
