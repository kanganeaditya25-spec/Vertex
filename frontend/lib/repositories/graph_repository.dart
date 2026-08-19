import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/knowledge_graph/graph_models.dart';

class GraphRepository {
  GraphRepository(this.preferences);

  final SharedPreferences preferences;
  static const _nodesKey = 'knowledge_graph_nodes_v1';
  static const _relationshipsKey = 'knowledge_graph_relationships_v1';
  static const _suggestionsKey = 'knowledge_graph_suggestions_v1';

  Future<List<GraphNodeModel>> loadNodes() async => _readList(
        _nodesKey,
        (json) => GraphNodeModel.fromJson(json),
      );

  Future<List<GraphRelationshipModel>> loadRelationships() async => _readList(
        _relationshipsKey,
        (json) => GraphRelationshipModel.fromJson(json),
      );

  Future<List<GraphSuggestionModel>> loadSuggestions() async => _readList(
        _suggestionsKey,
        (json) => GraphSuggestionModel.fromJson(json),
      );

  Future<GraphNodeModel> upsertNode({
    required String entityType,
    required String entityId,
    String workspaceId = '',
    String label = '',
    String contentText = '',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
    bool active = true,
  }) async {
    final nodes = await loadNodes();
    final key = GraphNodeModel.key(workspaceId, entityType, entityId);
    final index = nodes.indexWhere((item) => item.id == key);
    final current = index < 0
        ? GraphNodeModel(
            id: key,
            entityType: entityType.toLowerCase(),
            entityId: entityId,
            workspaceId: workspaceId,
            label: label.isEmpty ? '$entityType $entityId' : label,
            contentText: contentText,
            tags: tags,
            metadata: metadata,
            active: active,
            degree: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        : nodes[index].copyWith(
            label: label.isEmpty ? nodes[index].label : label,
            contentText: contentText,
            tags: tags,
            metadata: metadata,
            active: active,
            updatedAt: DateTime.now(),
          );
    if (index < 0) {
      nodes.add(current);
    } else {
      nodes[index] = current;
    }
    await _saveNodes(nodes);
    return current;
  }

  Future<GraphRelationshipModel?> ensureRelationship({
    required String workspaceId,
    required String sourceNodeId,
    required String targetNodeId,
    required String relationshipType,
    double weight = 1,
    double confidence = 1,
    String explanation = '',
    String source = 'manual',
    Map<String, dynamic> metadata = const {},
  }) async {
    if (sourceNodeId == targetNodeId) return null;
    final nodes = await loadNodes();
    final sourceNode =
        nodes.where((node) => node.id == sourceNodeId).firstOrNull;
    final targetNode =
        nodes.where((node) => node.id == targetNodeId).firstOrNull;
    if (sourceNode == null ||
        targetNode == null ||
        sourceNode.workspaceId != workspaceId ||
        targetNode.workspaceId != workspaceId) {
      return null;
    }
    final relationships = await loadRelationships();
    final normalized =
        relationshipType.trim().toLowerCase().replaceAll(' ', '_');
    final existingIndex = relationships.indexWhere((item) =>
        item.workspaceId == workspaceId &&
        item.sourceNodeId == sourceNodeId &&
        item.targetNodeId == targetNodeId &&
        item.relationshipType == normalized);
    final relationship = GraphRelationshipModel(
      id: existingIndex < 0
          ? _id('relationship')
          : relationships[existingIndex].id,
      workspaceId: workspaceId,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      relationshipType: normalized,
      weight: weight,
      confidence: confidence,
      explanation: explanation,
      source: source,
      metadata: metadata,
      createdAt: existingIndex < 0
          ? DateTime.now()
          : relationships[existingIndex].createdAt,
      updatedAt: DateTime.now(),
    );
    if (existingIndex < 0) {
      relationships.add(relationship);
      _adjustDegree(nodes, sourceNodeId, 1);
      _adjustDegree(nodes, targetNodeId, 1);
    } else {
      relationships[existingIndex] = relationship;
    }
    await _saveRelationships(relationships);
    await _saveNodes(nodes);
    return relationship;
  }

  Future<bool> removeRelationship(String relationshipId) async {
    final relationships = await loadRelationships();
    final index = relationships.indexWhere((item) => item.id == relationshipId);
    if (index < 0) return false;
    final relationship = relationships.removeAt(index);
    final nodes = await loadNodes();
    _adjustDegree(nodes, relationship.sourceNodeId, -1);
    _adjustDegree(nodes, relationship.targetNodeId, -1);
    await _saveRelationships(relationships);
    await _saveNodes(nodes);
    return true;
  }

  Future<GraphStatsModel> stats({String workspaceId = ''}) async {
    final nodes = (await loadNodes())
        .where((node) => node.workspaceId == workspaceId && node.active)
        .toList();
    final relationships = (await loadRelationships())
        .where((item) => item.workspaceId == workspaceId)
        .toList();
    final types = <String, int>{};
    for (final relationship in relationships) {
      types[relationship.relationshipType] =
          (types[relationship.relationshipType] ?? 0) + 1;
    }
    final possible = nodes.length * (nodes.length - 1);
    return GraphStatsModel(
      totalNodes: nodes.length,
      activeNodes: nodes.length,
      totalRelationships: relationships.length,
      relationshipTypes: types,
      graphDensity: possible <= 0 ? 0 : relationships.length / possible,
      connectedComponents: _components(nodes, relationships),
      orphanedNodes: nodes.where((node) => node.degree == 0).length,
      acceptedSuggestions: (await loadSuggestions())
          .where((item) =>
              item.workspaceId == workspaceId && item.status == 'accepted')
          .length,
    );
  }

  Future<List<GraphNodeModel>> search(String query,
      {String workspaceId = ''}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return (await loadNodes())
          .where((node) => node.workspaceId == workspaceId && node.active)
          .toList();
    }
    return (await loadNodes()).where((node) {
      if (node.workspaceId != workspaceId || !node.active) return false;
      final text =
          [node.label, node.contentText, ...node.tags].join(' ').toLowerCase();
      return text.contains(needle);
    }).toList();
  }

  Future<GraphPathResult> path(String sourceId, String targetId,
      {String workspaceId = ''}) async {
    if (sourceId == targetId) {
      return GraphPathResult(
          nodeIds: [sourceId], relationshipIds: const [], found: true);
    }
    final relationships = (await loadRelationships())
        .where((item) => item.workspaceId == workspaceId)
        .toList();
    final adjacent = <String, List<GraphRelationshipModel>>{};
    for (final relationship in relationships) {
      adjacent
          .putIfAbsent(relationship.sourceNodeId, () => [])
          .add(relationship);
      adjacent
          .putIfAbsent(relationship.targetNodeId, () => [])
          .add(relationship);
    }
    final queue = <_PathState>[
      _PathState(sourceId, [sourceId], const [])
    ];
    final visited = {sourceId};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final relationship
          in adjacent[current.nodeId] ?? const <GraphRelationshipModel>[]) {
        final next = relationship.sourceNodeId == current.nodeId
            ? relationship.targetNodeId
            : relationship.sourceNodeId;
        if (!visited.add(next)) continue;
        final nodes = [...current.nodeIds, next];
        final relationshipIds = [...current.relationshipIds, relationship.id];
        if (next == targetId) {
          return GraphPathResult(
              nodeIds: nodes, relationshipIds: relationshipIds, found: true);
        }
        queue.add(_PathState(next, nodes, relationshipIds));
      }
    }
    return const GraphPathResult(
        nodeIds: [], relationshipIds: [], found: false);
  }

  Future<List<GraphSuggestionModel>> suggestions(
      {String workspaceId = ''}) async {
    final nodes = (await loadNodes())
        .where((node) => node.workspaceId == workspaceId && node.active)
        .toList();
    final relationships = await loadRelationships();
    final suggestions = await loadSuggestions();
    for (var leftIndex = 0; leftIndex < nodes.length; leftIndex++) {
      for (var rightIndex = leftIndex + 1;
          rightIndex < nodes.length;
          rightIndex++) {
        final left = nodes[leftIndex];
        final right = nodes[rightIndex];
        final sharedTags = left.tags.toSet().intersection(right.tags.toSet());
        final textScore =
            _jaccard(_tokens(left.contentText), _tokens(right.contentText));
        final score = (textScore * 0.7 + (sharedTags.isNotEmpty ? 0.3 : 0))
            .clamp(0.0, 1.0);
        if (score < 0.28) continue;
        final type = textScore >= 0.2 ? 'similar_to' : 'related_to';
        final exists = relationships.any((item) =>
            item.workspaceId == workspaceId &&
            ((item.sourceNodeId == left.id && item.targetNodeId == right.id) ||
                (item.sourceNodeId == right.id &&
                    item.targetNodeId == left.id)) &&
            item.relationshipType == type);
        if (exists) continue;
        final explanation = <String>[
          if (textScore >= 0.2)
            '${(textScore * 100).round()}% shared content terms',
          if (sharedTags.isNotEmpty)
            'shared tags: ${sharedTags.take(4).join(', ')}',
        ].join('; ');
        final index = suggestions.indexWhere((item) =>
            item.workspaceId == workspaceId &&
            item.sourceNodeId == left.id &&
            item.targetNodeId == right.id &&
            item.relationshipType == type);
        final suggestion = GraphSuggestionModel(
          id: index < 0 ? _id('suggestion') : suggestions[index].id,
          workspaceId: workspaceId,
          sourceNodeId: left.id,
          targetNodeId: right.id,
          relationshipType: type,
          score: score.toDouble(),
          explanation: 'Suggested because $explanation.',
          status: index < 0 ? 'pending' : suggestions[index].status,
          createdAt: index < 0 ? DateTime.now() : suggestions[index].createdAt,
          updatedAt: DateTime.now(),
        );
        if (index < 0) {
          suggestions.add(suggestion);
        } else {
          suggestions[index] = suggestion;
        }
      }
    }
    await _saveSuggestions(suggestions);
    return suggestions
        .where((item) =>
            item.workspaceId == workspaceId && item.status == 'pending')
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));
  }

  Future<void> dismissSuggestion(GraphSuggestionModel suggestion) async {
    final suggestions = await loadSuggestions();
    final index = suggestions.indexWhere((item) => item.id == suggestion.id);
    if (index < 0) return;
    suggestions[index] = suggestion.copyWith(status: 'dismissed');
    await _saveSuggestions(suggestions);
  }

  Future<GraphRelationshipModel?> acceptSuggestion(
      GraphSuggestionModel suggestion) async {
    final relationship = await ensureRelationship(
      workspaceId: suggestion.workspaceId,
      sourceNodeId: suggestion.sourceNodeId,
      targetNodeId: suggestion.targetNodeId,
      relationshipType: suggestion.relationshipType,
      confidence: suggestion.score,
      explanation: suggestion.explanation,
      source: 'ai_suggestion',
    );
    if (relationship == null) return null;
    final suggestions = await loadSuggestions();
    final index = suggestions.indexWhere((item) => item.id == suggestion.id);
    if (index >= 0) {
      suggestions[index] = suggestion.copyWith(status: 'accepted');
    }
    await _saveSuggestions(suggestions);
    return relationship;
  }

  Future<List<GraphInsightModel>> insights({String workspaceId = ''}) async {
    final nodes = (await loadNodes())
        .where((node) => node.workspaceId == workspaceId && node.active)
        .toList();
    final statsSnapshot = await stats(workspaceId: workspaceId);
    final insights = <GraphInsightModel>[];
    final connected = [...nodes]
      ..sort((left, right) => right.degree.compareTo(left.degree));
    if (connected.isNotEmpty && connected.first.degree > 0) {
      insights.add(GraphInsightModel(
          insightType: 'most_connected',
          title: 'Most connected knowledge',
          explanation:
              'These items have the highest number of direct relationships.',
          nodeIds: connected.take(5).map((node) => node.id).toList(),
          score: connected.first.degree.toDouble()));
    }
    final orphaned = nodes.where((node) => node.degree == 0).toList();
    if (orphaned.isNotEmpty) {
      insights.add(GraphInsightModel(
          insightType: 'orphaned_items',
          title: 'Orphaned items',
          explanation: 'These active items have no graph relationships yet.',
          nodeIds: orphaned.take(25).map((node) => node.id).toList(),
          score: orphaned.length.toDouble()));
    }
    if (statsSnapshot.totalNodes > 1 && statsSnapshot.totalRelationships == 0) {
      insights.add(GraphInsightModel(
          insightType: 'missing_relationships',
          title: 'Add first connections',
          explanation:
              'Link projects, tasks, notes, and assets so their context is discoverable.',
          nodeIds: nodes.take(10).map((node) => node.id).toList(),
          score: 1));
    }
    return insights;
  }

  Future<List<DuplicateGroupModel>> duplicates(
      {String workspaceId = ''}) async {
    final nodes = (await loadNodes())
        .where((node) => node.workspaceId == workspaceId && node.active)
        .toList();
    final results = <DuplicateGroupModel>[];
    for (var leftIndex = 0; leftIndex < nodes.length; leftIndex++) {
      for (var rightIndex = leftIndex + 1;
          rightIndex < nodes.length;
          rightIndex++) {
        final left = nodes[leftIndex];
        final right = nodes[rightIndex];
        final sameHash = left.metadata['content_hash'] != null &&
            left.metadata['content_hash'] == right.metadata['content_hash'];
        final sameLabel =
            left.label.trim().toLowerCase() == right.label.trim().toLowerCase();
        final similarity =
            _jaccard(_tokens(left.contentText), _tokens(right.contentText));
        if (!sameHash && !sameLabel && similarity < 0.85) continue;
        results.add(DuplicateGroupModel(
            reason: sameHash
                ? 'same_content_hash'
                : sameLabel
                    ? 'same_label'
                    : 'similar_content',
            nodeIds: [left.id, right.id],
            explanation:
                'These items may be duplicates. Review before merging; no data was deleted.',
            score: sameHash || sameLabel ? 1 : similarity));
      }
    }
    return results;
  }

  Future<void> _saveNodes(List<GraphNodeModel> nodes) async =>
      preferences.setString(
          _nodesKey, jsonEncode(nodes.map((node) => node.toJson()).toList()));
  Future<void> _saveRelationships(
          List<GraphRelationshipModel> relationships) async =>
      preferences.setString(_relationshipsKey,
          jsonEncode(relationships.map((item) => item.toJson()).toList()));
  Future<void> _saveSuggestions(List<GraphSuggestionModel> suggestions) async =>
      preferences.setString(_suggestionsKey,
          jsonEncode(suggestions.map((item) => item.toJson()).toList()));

  Future<List<T>> _readList<T>(
      String key, T Function(Map<String, dynamic>) parse) async {
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  void _adjustDegree(List<GraphNodeModel> nodes, String nodeId, int delta) {
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index >= 0) {
      nodes[index] = nodes[index]
          .copyWith(degree: (nodes[index].degree + delta).clamp(0, 1000000));
    }
  }

  int _components(
      List<GraphNodeModel> nodes, List<GraphRelationshipModel> relationships) {
    final adjacency = <String, Set<String>>{};
    for (final relationship in relationships) {
      adjacency
          .putIfAbsent(relationship.sourceNodeId, () => {})
          .add(relationship.targetNodeId);
      adjacency
          .putIfAbsent(relationship.targetNodeId, () => {})
          .add(relationship.sourceNodeId);
    }
    final unseen = nodes.map((node) => node.id).toSet();
    var components = 0;
    while (unseen.isNotEmpty) {
      components++;
      final stack = [unseen.first]..removeWhere((_) => false);
      unseen.remove(stack.first);
      while (stack.isNotEmpty) {
        for (final neighbor
            in adjacency[stack.removeLast()] ?? const <String>{}) {
          if (unseen.remove(neighbor)) stack.add(neighbor);
        }
      }
    }
    return components;
  }

  Set<String> _tokens(String value) => RegExp(r'[A-Za-z0-9_]{2,}')
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => !{'the', 'and', 'for', 'with', 'from'}.contains(token))
      .toSet();

  double _jaccard(Set<String> left, Set<String> right) =>
      left.isEmpty || right.isEmpty
          ? 0
          : left.intersection(right).length / left.union(right).length;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

class GraphPathResult {
  const GraphPathResult(
      {required this.nodeIds,
      required this.relationshipIds,
      required this.found});
  final List<String> nodeIds;
  final List<String> relationshipIds;
  final bool found;
}

class DuplicateGroupModel {
  const DuplicateGroupModel(
      {required this.reason,
      required this.nodeIds,
      required this.explanation,
      required this.score});
  final String reason;
  final List<String> nodeIds;
  final String explanation;
  final double score;
}

class _PathState {
  const _PathState(this.nodeId, this.nodeIds, this.relationshipIds);
  final String nodeId;
  final List<String> nodeIds;
  final List<String> relationshipIds;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
