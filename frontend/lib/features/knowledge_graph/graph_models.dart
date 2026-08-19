import 'dart:convert';

class GraphNodeModel {
  const GraphNodeModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.workspaceId,
    required this.label,
    required this.contentText,
    required this.tags,
    required this.metadata,
    required this.active,
    required this.degree,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String workspaceId;
  final String label;
  final String contentText;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final bool active;
  final int degree;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GraphNodeModel.fromJson(Map<String, dynamic> json) => GraphNodeModel(
        id: '${json['id'] ?? ''}',
        entityType: '${json['entity_type'] ?? json['entityType'] ?? ''}',
        entityId: '${json['entity_id'] ?? json['entityId'] ?? ''}',
        workspaceId: '${json['workspace_id'] ?? json['workspaceId'] ?? ''}',
        label: '${json['label'] ?? ''}',
        contentText: '${json['content_text'] ?? json['contentText'] ?? ''}',
        tags: List<String>.from(json['tags'] ?? const []),
        metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
        active: json['active'] as bool? ?? true,
        degree: json['degree'] as int? ?? 0,
        createdAt:
            DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse('${json['updated_at'] ?? json['updatedAt']}') ??
                DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'workspace_id': workspaceId,
        'label': label,
        'content_text': contentText,
        'tags': tags,
        'metadata': metadata,
        'active': active,
        'degree': degree,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  GraphNodeModel copyWith({
    String? label,
    String? contentText,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    bool? active,
    int? degree,
    DateTime? updatedAt,
  }) =>
      GraphNodeModel(
        id: id,
        entityType: entityType,
        entityId: entityId,
        workspaceId: workspaceId,
        label: label ?? this.label,
        contentText: contentText ?? this.contentText,
        tags: tags ?? this.tags,
        metadata: metadata ?? this.metadata,
        active: active ?? this.active,
        degree: degree ?? this.degree,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static String key(String workspaceId, String entityType, String entityId) =>
      '${workspaceId.isEmpty ? '_global' : workspaceId}:${entityType.toLowerCase()}:$entityId';
}

class GraphRelationshipModel {
  const GraphRelationshipModel({
    required this.id,
    required this.workspaceId,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.relationshipType,
    required this.weight,
    required this.confidence,
    required this.explanation,
    required this.source,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String sourceNodeId;
  final String targetNodeId;
  final String relationshipType;
  final double weight;
  final double confidence;
  final String explanation;
  final String source;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GraphRelationshipModel.fromJson(Map<String, dynamic> json) =>
      GraphRelationshipModel(
        id: '${json['id'] ?? ''}',
        workspaceId: '${json['workspace_id'] ?? json['workspaceId'] ?? ''}',
        sourceNodeId: '${json['source_node_id'] ?? json['sourceNodeId'] ?? ''}',
        targetNodeId: '${json['target_node_id'] ?? json['targetNodeId'] ?? ''}',
        relationshipType:
            '${json['relationship_type'] ?? json['relationshipType'] ?? 'related_to'}',
        weight: (json['weight'] as num?)?.toDouble() ?? 1,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
        explanation: '${json['explanation'] ?? ''}',
        source: '${json['source'] ?? 'manual'}',
        metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
        createdAt:
            DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse('${json['updated_at'] ?? json['updatedAt']}') ??
                DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'relationship_type': relationshipType,
        'weight': weight,
        'confidence': confidence,
        'explanation': explanation,
        'source': source,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class GraphSuggestionModel {
  const GraphSuggestionModel({
    required this.id,
    required this.workspaceId,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.relationshipType,
    required this.score,
    required this.explanation,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String sourceNodeId;
  final String targetNodeId;
  final String relationshipType;
  final double score;
  final String explanation;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GraphSuggestionModel.fromJson(Map<String, dynamic> json) =>
      GraphSuggestionModel(
        id: '${json['id'] ?? ''}',
        workspaceId: '${json['workspace_id'] ?? json['workspaceId'] ?? ''}',
        sourceNodeId: '${json['source_node_id'] ?? json['sourceNodeId'] ?? ''}',
        targetNodeId: '${json['target_node_id'] ?? json['targetNodeId'] ?? ''}',
        relationshipType:
            '${json['relationship_type'] ?? json['relationshipType'] ?? 'related_to'}',
        score: (json['score'] as num?)?.toDouble() ?? 0,
        explanation: '${json['explanation'] ?? ''}',
        status: '${json['status'] ?? 'pending'}',
        createdAt:
            DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse('${json['updated_at'] ?? json['updatedAt']}') ??
                DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'relationship_type': relationshipType,
        'score': score,
        'explanation': explanation,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  GraphSuggestionModel copyWith({String? status}) => GraphSuggestionModel(
        id: id,
        workspaceId: workspaceId,
        sourceNodeId: sourceNodeId,
        targetNodeId: targetNodeId,
        relationshipType: relationshipType,
        score: score,
        explanation: explanation,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

class GraphStatsModel {
  const GraphStatsModel({
    this.totalNodes = 0,
    this.activeNodes = 0,
    this.totalRelationships = 0,
    this.relationshipTypes = const {},
    this.graphDensity = 0,
    this.connectedComponents = 0,
    this.orphanedNodes = 0,
    this.acceptedSuggestions = 0,
  });

  final int totalNodes;
  final int activeNodes;
  final int totalRelationships;
  final Map<String, int> relationshipTypes;
  final double graphDensity;
  final int connectedComponents;
  final int orphanedNodes;
  final int acceptedSuggestions;

  factory GraphStatsModel.fromJson(Map<String, dynamic> json) =>
      GraphStatsModel(
        totalNodes: json['total_nodes'] as int? ?? 0,
        activeNodes: json['active_nodes'] as int? ?? 0,
        totalRelationships: json['total_relationships'] as int? ?? 0,
        relationshipTypes:
            Map<String, int>.from(json['relationship_types'] ?? const {}),
        graphDensity: (json['graph_density'] as num?)?.toDouble() ?? 0,
        connectedComponents: json['connected_components'] as int? ?? 0,
        orphanedNodes: json['orphaned_nodes'] as int? ?? 0,
        acceptedSuggestions: json['accepted_suggestions'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'total_nodes': totalNodes,
        'active_nodes': activeNodes,
        'total_relationships': totalRelationships,
        'relationship_types': relationshipTypes,
        'graph_density': graphDensity,
        'connected_components': connectedComponents,
        'orphaned_nodes': orphanedNodes,
        'accepted_suggestions': acceptedSuggestions,
      };
}

class GraphInsightModel {
  const GraphInsightModel({
    required this.insightType,
    required this.title,
    required this.explanation,
    required this.nodeIds,
    required this.score,
  });

  final String insightType;
  final String title;
  final String explanation;
  final List<String> nodeIds;
  final double score;

  factory GraphInsightModel.fromJson(Map<String, dynamic> json) =>
      GraphInsightModel(
        insightType: '${json['insight_type'] ?? ''}',
        title: '${json['title'] ?? ''}',
        explanation: '${json['explanation'] ?? ''}',
        nodeIds: List<String>.from(json['node_ids'] ?? const []),
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

Map<String, dynamic> decodeMap(String value) {
  try {
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  } catch (_) {
    return <String, dynamic>{};
  }
}
