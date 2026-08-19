import '../knowledge_graph/graph_models.dart';

class SearchFiltersModel {
  const SearchFiltersModel({
    this.workspaceId = '',
    this.projectId = '',
    this.category = '',
    this.tags = const [],
    this.sourceTypes = const [],
    this.aiGenerated,
    this.favorite,
    this.recentOnly = false,
  });

  final String workspaceId;
  final String projectId;
  final String category;
  final List<String> tags;
  final List<String> sourceTypes;
  final bool? aiGenerated;
  final bool? favorite;
  final bool recentOnly;

  SearchFiltersModel copyWith({
    String? workspaceId,
    String? projectId,
    String? category,
    List<String>? tags,
    List<String>? sourceTypes,
    bool? aiGenerated,
    bool clearAiGenerated = false,
    bool? favorite,
    bool clearFavorite = false,
    bool? recentOnly,
  }) =>
      SearchFiltersModel(
        workspaceId: workspaceId ?? this.workspaceId,
        projectId: projectId ?? this.projectId,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        sourceTypes: sourceTypes ?? this.sourceTypes,
        aiGenerated: clearAiGenerated ? null : aiGenerated ?? this.aiGenerated,
        favorite: clearFavorite ? null : favorite ?? this.favorite,
        recentOnly: recentOnly ?? this.recentOnly,
      );

  Map<String, dynamic> toJson() => {
        'workspace_id': workspaceId,
        'project_id': projectId,
        'category': category,
        'tags': tags,
        'source_types': sourceTypes,
        'ai_generated': aiGenerated,
        'favorite': favorite,
        'recent_only': recentOnly,
      };
}

class SearchResultModel {
  const SearchResultModel({
    required this.documentId,
    required this.title,
    required this.score,
    required this.snippet,
    required this.sourceType,
    required this.metadata,
    this.sourceUrl = '',
    this.preview = '',
    this.thumbnailUrl = '',
    this.summary = '',
    this.relatedItemIds = const [],
    this.aiInsights = const [],
    this.quickActions = const ['open'],
  });

  final String documentId;
  final String title;
  final double score;
  final String snippet;
  final String sourceType;
  final String sourceUrl;
  final Map<String, dynamic> metadata;
  final String preview;
  final String thumbnailUrl;
  final String summary;
  final List<String> relatedItemIds;
  final List<String> aiInsights;
  final List<String> quickActions;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) =>
      SearchResultModel(
        documentId: '${json['document_id'] ?? json['documentId'] ?? ''}',
        title: '${json['title'] ?? ''}',
        score: (json['score'] as num?)?.toDouble() ?? 0,
        snippet: '${json['snippet'] ?? ''}',
        sourceType: '${json['source_type'] ?? json['sourceType'] ?? ''}',
        sourceUrl: '${json['source_url'] ?? json['sourceUrl'] ?? ''}',
        metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
        preview: '${json['preview'] ?? ''}',
        thumbnailUrl: '${json['thumbnail_url'] ?? json['thumbnailUrl'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        relatedItemIds: List<String>.from(
            json['related_item_ids'] ?? json['relatedItemIds'] ?? const []),
        aiInsights: List<String>.from(
            json['ai_insights'] ?? json['aiInsights'] ?? const []),
        quickActions: List<String>.from(
            json['quick_actions'] ?? json['quickActions'] ?? const ['open']),
      );
}

class CommandItemModel {
  const CommandItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.action,
    this.route = '',
    this.keywords = const [],
    this.icon = 'circle',
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String action;
  final String route;
  final List<String> keywords;
  final String icon;
}

class SearchHistoryModel {
  const SearchHistoryModel(
      {required this.query, required this.createdAt, this.resultCount = 0});
  final String query;
  final DateTime createdAt;
  final int resultCount;
}

class SavedSearchModel {
  const SavedSearchModel(
      {required this.name,
      required this.query,
      this.filters = const SearchFiltersModel(),
      this.favorite = false});
  final String name;
  final String query;
  final SearchFiltersModel filters;
  final bool favorite;
}

class StudyResourceModel {
  const StudyResourceModel(
      {required this.sourceId,
      required this.title,
      required this.resourceType,
      required this.content,
      this.cached = false});
  final String sourceId;
  final String title;
  final String resourceType;
  final Map<String, dynamic> content;
  final bool cached;
}

class SmartCollectionModel {
  const SmartCollectionModel(
      {required this.name,
      required this.description,
      required this.itemIds,
      this.aiRecommended = false});
  final String name;
  final String description;
  final List<String> itemIds;
  final bool aiRecommended;
}

class DiscoveryModel {
  const DiscoveryModel(
      {required this.sourceId,
      required this.relatedResults,
      required this.relatedNodeIds,
      required this.forgottenItems,
      required this.missingLinks,
      required this.recommendedCollections});
  final String sourceId;
  final List<SearchResultModel> relatedResults;
  final List<String> relatedNodeIds;
  final List<SearchResultModel> forgottenItems;
  final List<String> missingLinks;
  final List<String> recommendedCollections;
}

class SearchState {
  const SearchState({
    required this.results,
    required this.history,
    required this.savedSearches,
    required this.collections,
    required this.commands,
    required this.query,
    required this.filters,
    this.searchType = 'keyword',
    this.selectedResult,
    this.studyResource,
    this.discovery,
  });

  final List<SearchResultModel> results;
  final List<SearchHistoryModel> history;
  final List<SavedSearchModel> savedSearches;
  final List<SmartCollectionModel> collections;
  final List<CommandItemModel> commands;
  final String query;
  final SearchFiltersModel filters;
  final String searchType;
  final SearchResultModel? selectedResult;
  final StudyResourceModel? studyResource;
  final DiscoveryModel? discovery;

  SearchState copyWith({
    List<SearchResultModel>? results,
    List<SearchHistoryModel>? history,
    List<SavedSearchModel>? savedSearches,
    List<SmartCollectionModel>? collections,
    List<CommandItemModel>? commands,
    String? query,
    SearchFiltersModel? filters,
    String? searchType,
    SearchResultModel? selectedResult,
    bool clearSelectedResult = false,
    StudyResourceModel? studyResource,
    bool clearStudyResource = false,
    DiscoveryModel? discovery,
  }) =>
      SearchState(
        results: results ?? this.results,
        history: history ?? this.history,
        savedSearches: savedSearches ?? this.savedSearches,
        collections: collections ?? this.collections,
        commands: commands ?? this.commands,
        query: query ?? this.query,
        filters: filters ?? this.filters,
        searchType: searchType ?? this.searchType,
        selectedResult:
            clearSelectedResult ? null : selectedResult ?? this.selectedResult,
        studyResource:
            clearStudyResource ? null : studyResource ?? this.studyResource,
        discovery: discovery ?? this.discovery,
      );

  List<GraphNodeModel> get relatedGraphNodes => const [];
}
