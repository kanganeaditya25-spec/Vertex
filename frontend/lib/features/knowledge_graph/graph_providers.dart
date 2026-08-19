import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/graph_repository.dart';
import 'graph_models.dart';

final graphControllerProvider =
    AsyncNotifierProvider<GraphController, GraphState>(GraphController.new);

class GraphState {
  const GraphState({
    required this.nodes,
    required this.relationships,
    required this.suggestions,
    required this.stats,
    required this.insights,
    this.query = '',
    this.workspaceId = '',
    this.selectedNodeId,
    this.view = 'network',
  });

  final List<GraphNodeModel> nodes;
  final List<GraphRelationshipModel> relationships;
  final List<GraphSuggestionModel> suggestions;
  final GraphStatsModel stats;
  final List<GraphInsightModel> insights;
  final String query;
  final String workspaceId;
  final String? selectedNodeId;
  final String view;

  List<GraphNodeModel> get visibleNodes {
    final needle = query.trim().toLowerCase();
    return nodes.where((node) {
      if (node.workspaceId != workspaceId || !node.active) return false;
      if (needle.isEmpty) return true;
      return [node.label, node.entityType, node.contentText, ...node.tags]
          .join(' ')
          .toLowerCase()
          .contains(needle);
    }).toList();
  }

  List<GraphRelationshipModel> get visibleRelationships {
    final visibleIds = visibleNodes.map((node) => node.id).toSet();
    return relationships
        .where((relationship) =>
            relationship.workspaceId == workspaceId &&
            visibleIds.contains(relationship.sourceNodeId) &&
            visibleIds.contains(relationship.targetNodeId))
        .toList();
  }

  GraphNodeModel? get selectedNode {
    if (selectedNodeId == null) return null;
    for (final node in nodes) {
      if (node.id == selectedNodeId) return node;
    }
    return null;
  }

  GraphState copyWith({
    List<GraphNodeModel>? nodes,
    List<GraphRelationshipModel>? relationships,
    List<GraphSuggestionModel>? suggestions,
    GraphStatsModel? stats,
    List<GraphInsightModel>? insights,
    String? query,
    String? workspaceId,
    String? selectedNodeId,
    bool clearSelection = false,
    String? view,
  }) =>
      GraphState(
        nodes: nodes ?? this.nodes,
        relationships: relationships ?? this.relationships,
        suggestions: suggestions ?? this.suggestions,
        stats: stats ?? this.stats,
        insights: insights ?? this.insights,
        query: query ?? this.query,
        workspaceId: workspaceId ?? this.workspaceId,
        selectedNodeId:
            clearSelection ? null : selectedNodeId ?? this.selectedNodeId,
        view: view ?? this.view,
      );
}

class GraphController extends AsyncNotifier<GraphState> {
  GraphRepository? _repository;

  @override
  Future<GraphState> build() async {
    final preferences = await SharedPreferences.getInstance();
    _repository = GraphRepository(preferences);
    return _load();
  }

  Future<GraphState> _load({GraphState? current}) async {
    final nodes = await _repository!.loadNodes();
    final relationships = await _repository!.loadRelationships();
    final suggestions = await _repository!.loadSuggestions();
    final workspaceId = current?.workspaceId ?? '';
    return GraphState(
      nodes: nodes,
      relationships: relationships,
      suggestions: suggestions
          .where((suggestion) => suggestion.workspaceId == workspaceId)
          .toList(),
      stats: await _repository!.stats(workspaceId: workspaceId),
      insights: await _repository!.insights(workspaceId: workspaceId),
      query: current?.query ?? '',
      workspaceId: workspaceId,
      selectedNodeId: current?.selectedNodeId,
      view: current?.view ?? 'network',
    );
  }

  Future<void> refresh() async {
    if (_repository == null) return;
    final current = state.valueOrNull;
    state = AsyncData(await _load(current: current));
  }

  Future<GraphNodeModel?> upsertNode({
    required String entityType,
    required String entityId,
    required String label,
    String contentText = '',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_repository == null) return null;
    final current = state.valueOrNull;
    final node = await _repository!.upsertNode(
      entityType: entityType,
      entityId: entityId,
      workspaceId: current?.workspaceId ?? '',
      label: label,
      contentText: contentText,
      tags: tags,
      metadata: metadata,
    );
    await refresh();
    return node;
  }

  Future<void> link({
    required String sourceNodeId,
    required String targetNodeId,
    required String relationshipType,
    String explanation = '',
  }) async {
    final current = state.valueOrNull;
    if (_repository == null || current == null) return;
    await _repository!.ensureRelationship(
      workspaceId: current.workspaceId,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      relationshipType: relationshipType,
      explanation: explanation,
    );
    await refresh();
  }

  Future<void> unlink(String relationshipId) async {
    await _repository?.removeRelationship(relationshipId);
    await refresh();
  }

  Future<void> generateSuggestions() async {
    final current = state.valueOrNull;
    if (_repository == null || current == null) return;
    await _repository!.suggestions(workspaceId: current.workspaceId);
    await refresh();
  }

  Future<void> acceptSuggestion(GraphSuggestionModel suggestion) async {
    await _repository?.acceptSuggestion(suggestion);
    await refresh();
  }

  Future<void> dismissSuggestion(GraphSuggestionModel suggestion) async {
    await _repository?.dismissSuggestion(suggestion);
    await refresh();
  }

  void setQuery(String query) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(query: query));
  }

  Future<void> setWorkspace(String workspaceId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
        current.copyWith(workspaceId: workspaceId, clearSelection: true));
    await refresh();
  }

  void selectNode(String? nodeId) {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        selectedNodeId: nodeId,
        clearSelection: nodeId == null,
      ));
    }
  }

  void setView(String view) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(view: view));
  }
}
