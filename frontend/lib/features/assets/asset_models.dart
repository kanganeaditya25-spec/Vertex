import 'dart:convert';

class AssetModel {
  const AssetModel({
    required this.id,
    required this.name,
    required this.assetType,
    required this.sourceKind,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileHash,
    required this.storageKey,
    required this.sourceUrl,
    required this.previewText,
    required this.ocrText,
    required this.thumbnailKey,
    required this.workspaceId,
    required this.projectId,
    required this.folderId,
    required this.category,
    required this.tags,
    required this.metadata,
    required this.linkedTaskIds,
    required this.linkedNoteIds,
    required this.linkedEventIds,
    required this.linkedGoalIds,
    required this.linkedReminderIds,
    required this.linkedAssistantThreadIds,
    required this.favorite,
    required this.pinned,
    required this.archived,
    required this.trashed,
    required this.hidden,
    required this.encrypted,
    required this.locked,
    required this.readingProgress,
    required this.version,
    required this.createdAt,
    required this.modifiedAt,
    this.contentBase64 = '',
    this.offlineContent = false,
  });

  factory AssetModel.create({
    required String id,
    required String name,
    required String assetType,
    required String sourceKind,
    String extension = '',
    String mimeType = 'application/octet-stream',
    int sizeBytes = 0,
    String fileHash = '',
    String storageKey = '',
    String sourceUrl = '',
    String previewText = '',
    String ocrText = '',
    String thumbnailKey = '',
    String workspaceId = '',
    String projectId = '',
    String folderId = 'root',
    String category = 'uncategorized',
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
    String contentBase64 = '',
    bool offlineContent = false,
  }) =>
      AssetModel(
        id: id,
        name: name,
        assetType: assetType,
        sourceKind: sourceKind,
        extension: extension,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        fileHash: fileHash,
        storageKey: storageKey,
        sourceUrl: sourceUrl,
        previewText: previewText,
        ocrText: ocrText,
        thumbnailKey: thumbnailKey,
        workspaceId: workspaceId,
        projectId: projectId,
        folderId: folderId,
        category: category,
        tags: List.unmodifiable(tags),
        metadata: Map.unmodifiable(metadata),
        linkedTaskIds: const [],
        linkedNoteIds: const [],
        linkedEventIds: const [],
        linkedGoalIds: const [],
        linkedReminderIds: const [],
        linkedAssistantThreadIds: const [],
        favorite: false,
        pinned: false,
        archived: false,
        trashed: false,
        hidden: false,
        encrypted: false,
        locked: false,
        readingProgress: 0,
        version: 1,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        contentBase64: contentBase64,
        offlineContent: offlineContent,
      );

  final String id;
  final String name;
  final String assetType;
  final String sourceKind;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final String fileHash;
  final String storageKey;
  final String sourceUrl;
  final String previewText;
  final String ocrText;
  final String thumbnailKey;
  final String workspaceId;
  final String projectId;
  final String folderId;
  final String category;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final List<String> linkedTaskIds;
  final List<String> linkedNoteIds;
  final List<String> linkedEventIds;
  final List<String> linkedGoalIds;
  final List<String> linkedReminderIds;
  final List<String> linkedAssistantThreadIds;
  final bool favorite;
  final bool pinned;
  final bool archived;
  final bool trashed;
  final bool hidden;
  final bool encrypted;
  final bool locked;
  final double readingProgress;
  final int version;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String contentBase64;
  final bool offlineContent;

  bool get isUrl => sourceKind == 'url';
  bool get isImage => assetType == 'image';
  bool get isText => assetType == 'text' || assetType == 'code';
  bool get isAvailableOffline => isUrl || offlineContent;
  String get extensionLabel => extension.isEmpty
      ? assetType.toUpperCase()
      : extension.replaceFirst('.', '').toUpperCase();

  AssetModel copyWith({
    String? name,
    String? folderId,
    String? workspaceId,
    String? projectId,
    String? category,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    String? sourceUrl,
    String? previewText,
    String? ocrText,
    bool? favorite,
    bool? pinned,
    bool? archived,
    bool? trashed,
    bool? hidden,
    bool? encrypted,
    bool? locked,
    double? readingProgress,
    List<String>? linkedTaskIds,
    List<String>? linkedNoteIds,
    List<String>? linkedEventIds,
    List<String>? linkedGoalIds,
    List<String>? linkedReminderIds,
    List<String>? linkedAssistantThreadIds,
  }) =>
      AssetModel(
        id: id,
        name: name ?? this.name,
        assetType: assetType,
        sourceKind: sourceKind,
        extension: extension,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        fileHash: fileHash,
        storageKey: storageKey,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        previewText: previewText ?? this.previewText,
        ocrText: ocrText ?? this.ocrText,
        thumbnailKey: thumbnailKey,
        workspaceId: workspaceId ?? this.workspaceId,
        projectId: projectId ?? this.projectId,
        folderId: folderId ?? this.folderId,
        category: category ?? this.category,
        tags: List.unmodifiable(tags ?? this.tags),
        metadata: Map.unmodifiable(metadata ?? this.metadata),
        linkedTaskIds: List.unmodifiable(linkedTaskIds ?? this.linkedTaskIds),
        linkedNoteIds: List.unmodifiable(linkedNoteIds ?? this.linkedNoteIds),
        linkedEventIds:
            List.unmodifiable(linkedEventIds ?? this.linkedEventIds),
        linkedGoalIds: List.unmodifiable(linkedGoalIds ?? this.linkedGoalIds),
        linkedReminderIds:
            List.unmodifiable(linkedReminderIds ?? this.linkedReminderIds),
        linkedAssistantThreadIds: List.unmodifiable(
            linkedAssistantThreadIds ?? this.linkedAssistantThreadIds),
        favorite: favorite ?? this.favorite,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
        trashed: trashed ?? this.trashed,
        hidden: hidden ?? this.hidden,
        encrypted: encrypted ?? this.encrypted,
        locked: locked ?? this.locked,
        readingProgress: readingProgress ?? this.readingProgress,
        version: version + 1,
        createdAt: createdAt,
        modifiedAt: DateTime.now(),
        contentBase64: contentBase64,
        offlineContent: offlineContent,
      );

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] ?? json['metadata_json'];
    return AssetModel(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Untitled asset'}',
      assetType: '${json['asset_type'] ?? json['assetType'] ?? 'file'}',
      sourceKind: '${json['source_kind'] ?? json['sourceKind'] ?? 'file'}',
      extension: '${json['extension'] ?? ''}',
      mimeType:
          '${json['mime_type'] ?? json['mimeType'] ?? 'application/octet-stream'}',
      sizeBytes: _int(json['size_bytes'] ?? json['sizeBytes']),
      fileHash: '${json['file_hash'] ?? json['fileHash'] ?? ''}',
      storageKey: '${json['storage_key'] ?? json['storageKey'] ?? ''}',
      sourceUrl: '${json['source_url'] ?? json['sourceUrl'] ?? ''}',
      previewText: '${json['preview_text'] ?? json['previewText'] ?? ''}',
      ocrText: '${json['ocr_text'] ?? json['ocrText'] ?? ''}',
      thumbnailKey: '${json['thumbnail_key'] ?? json['thumbnailKey'] ?? ''}',
      workspaceId: '${json['workspace_id'] ?? json['workspaceId'] ?? ''}',
      projectId: '${json['project_id'] ?? json['projectId'] ?? ''}',
      folderId: '${json['folder_id'] ?? json['folderId'] ?? 'root'}',
      category: '${json['category'] ?? 'uncategorized'}',
      tags: _strings(json['tags']),
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : <String, dynamic>{},
      linkedTaskIds: _strings(json['linked_task_ids'] ?? json['linkedTaskIds']),
      linkedNoteIds: _strings(json['linked_note_ids'] ?? json['linkedNoteIds']),
      linkedEventIds:
          _strings(json['linked_event_ids'] ?? json['linkedEventIds']),
      linkedGoalIds: _strings(json['linked_goal_ids'] ?? json['linkedGoalIds']),
      linkedReminderIds:
          _strings(json['linked_reminder_ids'] ?? json['linkedReminderIds']),
      linkedAssistantThreadIds: _strings(json['linked_assistant_thread_ids'] ??
          json['linkedAssistantThreadIds']),
      favorite: json['favorite'] == true,
      pinned: json['pinned'] == true,
      archived: json['archived'] == true,
      trashed: json['trashed'] == true,
      hidden: json['hidden'] == true,
      encrypted: json['encrypted'] == true,
      locked: json['locked'] == true,
      readingProgress:
          _double(json['reading_progress'] ?? json['readingProgress']),
      version: _int(json['version'], fallback: 1),
      createdAt:
          _date(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      modifiedAt:
          _date(json['modified_at'] ?? json['modifiedAt']) ?? DateTime.now(),
      contentBase64: '${json['content_base64'] ?? json['contentBase64'] ?? ''}',
      offlineContent:
          json['offline_content'] == true || json['offlineContent'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'asset_type': assetType,
        'source_kind': sourceKind,
        'extension': extension,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'file_hash': fileHash,
        'storage_key': storageKey,
        'source_url': sourceUrl,
        'preview_text': previewText,
        'ocr_text': ocrText,
        'thumbnail_key': thumbnailKey,
        'workspace_id': workspaceId,
        'project_id': projectId,
        'folder_id': folderId,
        'category': category,
        'tags': tags,
        'metadata': metadata,
        'linked_task_ids': linkedTaskIds,
        'linked_note_ids': linkedNoteIds,
        'linked_event_ids': linkedEventIds,
        'linked_goal_ids': linkedGoalIds,
        'linked_reminder_ids': linkedReminderIds,
        'linked_assistant_thread_ids': linkedAssistantThreadIds,
        'favorite': favorite,
        'pinned': pinned,
        'archived': archived,
        'trashed': trashed,
        'hidden': hidden,
        'encrypted': encrypted,
        'locked': locked,
        'reading_progress': readingProgress,
        'version': version,
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String(),
        'content_base64': contentBase64,
        'offline_content': offlineContent,
      };
}

class AssetFolderModel {
  const AssetFolderModel(
      {required this.id,
      required this.name,
      required this.parentId,
      required this.smartQuery,
      required this.archived,
      required this.createdAt,
      required this.modifiedAt});
  final String id;
  final String name;
  final String parentId;
  final String smartQuery;
  final bool archived;
  final DateTime createdAt;
  final DateTime modifiedAt;

  factory AssetFolderModel.fromJson(Map<String, dynamic> json) =>
      AssetFolderModel(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? ''}',
          parentId: '${json['parent_id'] ?? json['parentId'] ?? 'root'}',
          smartQuery: '${json['smart_query'] ?? json['smartQuery'] ?? ''}',
          archived: json['archived'] == true,
          createdAt:
              _date(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
          modifiedAt: _date(json['modified_at'] ?? json['modifiedAt']) ??
              DateTime.now());
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'smart_query': smartQuery,
        'archived': archived,
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String()
      };
}

class AssetCollectionModel {
  const AssetCollectionModel(
      {required this.id,
      required this.name,
      required this.description,
      required this.assetIds,
      required this.passwordProtected,
      required this.createdAt,
      required this.modifiedAt});
  final String id;
  final String name;
  final String description;
  final List<String> assetIds;
  final bool passwordProtected;
  final DateTime createdAt;
  final DateTime modifiedAt;

  factory AssetCollectionModel.fromJson(Map<String, dynamic> json) =>
      AssetCollectionModel(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? ''}',
          description: '${json['description'] ?? ''}',
          assetIds: _strings(json['asset_ids'] ?? json['assetIds']),
          passwordProtected: json['password_protected'] == true ||
              json['passwordProtected'] == true,
          createdAt:
              _date(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
          modifiedAt: _date(json['modified_at'] ?? json['modifiedAt']) ??
              DateTime.now());
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'asset_ids': assetIds,
        'password_protected': passwordProtected,
        'created_at': createdAt.toIso8601String(),
        'modified_at': modifiedAt.toIso8601String()
      };
}

class AssetVersionModel {
  const AssetVersionModel(
      {required this.id,
      required this.assetId,
      required this.version,
      required this.action,
      required this.name,
      required this.fileHash,
      required this.sizeBytes,
      required this.createdAt});
  final String id;
  final String assetId;
  final int version;
  final String action;
  final String name;
  final String fileHash;
  final int sizeBytes;
  final DateTime createdAt;

  factory AssetVersionModel.fromJson(Map<String, dynamic> json) =>
      AssetVersionModel(
          id: '${json['id'] ?? ''}',
          assetId: '${json['asset_id'] ?? json['assetId'] ?? ''}',
          version: _int(json['version'], fallback: 1),
          action: '${json['action'] ?? 'edit'}',
          name: '${json['name'] ?? ''}',
          fileHash: '${json['file_hash'] ?? json['fileHash'] ?? ''}',
          sizeBytes: _int(json['size_bytes'] ?? json['sizeBytes']),
          createdAt:
              _date(json['created_at'] ?? json['createdAt']) ?? DateTime.now());
  Map<String, dynamic> toJson() => {
        'id': id,
        'asset_id': assetId,
        'version': version,
        'action': action,
        'name': name,
        'file_hash': fileHash,
        'size_bytes': sizeBytes,
        'created_at': createdAt.toIso8601String()
      };
}

class AssetStatsModel {
  const AssetStatsModel(
      {this.totalStorageBytes = 0,
      this.fileCount = 0,
      this.archivedCount = 0,
      this.trashedCount = 0,
      this.favoriteCount = 0,
      this.categoryCounts = const {},
      this.duplicateGroups = const []});
  final int totalStorageBytes;
  final int fileCount;
  final int archivedCount;
  final int trashedCount;
  final int favoriteCount;
  final Map<String, int> categoryCounts;
  final List<List<String>> duplicateGroups;
}

int _int(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : <String>[];
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
String prettyJson(Map<String, dynamic> value) =>
    const JsonEncoder.withIndent('  ').convert(value);
