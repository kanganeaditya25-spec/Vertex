class NoteBlock {
  const NoteBlock(
      {required this.id,
      required this.blockType,
      required this.content,
      this.position = 0,
      this.checked = false,
      this.collapsed = false,
      this.metadata = const {}});

  final String id;
  final String blockType;
  final String content;
  final int position;
  final bool checked;
  final bool collapsed;
  final Map<String, dynamic> metadata;

  NoteBlock copyWith(
          {String? blockType,
          String? content,
          int? position,
          bool? checked,
          bool? collapsed,
          Map<String, dynamic>? metadata}) =>
      NoteBlock(
          id: id,
          blockType: blockType ?? this.blockType,
          content: content ?? this.content,
          position: position ?? this.position,
          checked: checked ?? this.checked,
          collapsed: collapsed ?? this.collapsed,
          metadata: metadata ?? this.metadata);

  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock(
      id: json['id'] as String? ?? '',
      blockType: json['block_type'] as String? ??
          json['blockType'] as String? ??
          'paragraph',
      content: json['content'] as String? ?? '',
      position: _int(json['position']),
      checked: json['checked'] as bool? ?? false,
      collapsed: json['collapsed'] as bool? ?? false,
      metadata: (json['metadata'] as Map<dynamic, dynamic>? ?? const {})
          .map((key, value) => MapEntry('$key', value)));

  Map<String, dynamic> toJson() => {
        'id': id,
        'blockType': blockType,
        'content': content,
        'position': position,
        'checked': checked,
        'collapsed': collapsed,
        'metadata': metadata
      };
}

class NoteLink {
  const NoteLink(
      {required this.noteId, required this.title, required this.direction});
  final String noteId;
  final String title;
  final String direction;
}

class NoteModel {
  const NoteModel(
      {required this.id,
      required this.title,
      this.noteType = 'rich',
      this.summary = '',
      this.blocks = const [],
      this.folderId,
      this.workspace,
      this.projectId,
      this.tags = const [],
      this.color,
      this.icon,
      this.pinned = false,
      this.favorite = false,
      this.archived = false,
      this.deleted = false,
      this.wordCount = 0,
      this.readingTimeMinutes = 0,
      this.knowledgeScore = 0,
      this.importanceScore = 50,
      this.version = 1,
      this.syncStatus = 'pending',
      this.createdAt,
      this.updatedAt,
      this.outgoingNoteIds = const [],
      this.incomingNoteIds = const []});

  final String id;
  final String title;
  final String noteType;
  final String summary;
  final List<NoteBlock> blocks;
  final String? folderId;
  final String? workspace;
  final String? projectId;
  final List<String> tags;
  final String? color;
  final String? icon;
  final bool pinned;
  final bool favorite;
  final bool archived;
  final bool deleted;
  final int wordCount;
  final int readingTimeMinutes;
  final double knowledgeScore;
  final double importanceScore;
  final int version;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> outgoingNoteIds;
  final List<String> incomingNoteIds;

  int get checklistCount =>
      blocks.where((block) => block.blockType == 'checklist').length;
  int get completedChecklistCount => blocks
      .where((block) => block.blockType == 'checklist' && block.checked)
      .length;
  double get checklistProgress =>
      checklistCount == 0 ? 0 : completedChecklistCount / checklistCount;
  bool get hasLinks => outgoingNoteIds.isNotEmpty || incomingNoteIds.isNotEmpty;

  NoteModel copyWith(
          {String? title,
          String? noteType,
          String? summary,
          List<NoteBlock>? blocks,
          String? folderId,
          String? workspace,
          String? projectId,
          List<String>? tags,
          String? color,
          String? icon,
          bool? pinned,
          bool? favorite,
          bool? archived,
          bool? deleted,
          int? wordCount,
          int? readingTimeMinutes,
          double? knowledgeScore,
          double? importanceScore,
          int? version,
          String? syncStatus,
          DateTime? createdAt,
          DateTime? updatedAt,
          List<String>? outgoingNoteIds,
          List<String>? incomingNoteIds}) =>
      NoteModel(
          id: id,
          title: title ?? this.title,
          noteType: noteType ?? this.noteType,
          summary: summary ?? this.summary,
          blocks: blocks ?? this.blocks,
          folderId: folderId ?? this.folderId,
          workspace: workspace ?? this.workspace,
          projectId: projectId ?? this.projectId,
          tags: tags ?? this.tags,
          color: color ?? this.color,
          icon: icon ?? this.icon,
          pinned: pinned ?? this.pinned,
          favorite: favorite ?? this.favorite,
          archived: archived ?? this.archived,
          deleted: deleted ?? this.deleted,
          wordCount: wordCount ?? this.wordCount,
          readingTimeMinutes: readingTimeMinutes ?? this.readingTimeMinutes,
          knowledgeScore: knowledgeScore ?? this.knowledgeScore,
          importanceScore: importanceScore ?? this.importanceScore,
          version: version ?? this.version,
          syncStatus: syncStatus ?? this.syncStatus,
          createdAt: createdAt ?? this.createdAt,
          updatedAt: updatedAt ?? this.updatedAt,
          outgoingNoteIds: outgoingNoteIds ?? this.outgoingNoteIds,
          incomingNoteIds: incomingNoteIds ?? this.incomingNoteIds);

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      noteType:
          json['note_type'] as String? ?? json['noteType'] as String? ?? 'rich',
      summary: json['summary'] as String? ?? '',
      blocks: (json['blocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NoteBlock.fromJson)
          .toList(),
      folderId: json['folder_id'] as String? ?? json['folderId'] as String?,
      workspace: json['workspace'] as String?,
      projectId: json['project_id'] as String? ?? json['projectId'] as String?,
      tags: _strings(json['tags']),
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      favorite: json['favorite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      wordCount: _int(json['word_count'] ?? json['wordCount']),
      readingTimeMinutes:
          _int(json['reading_time_minutes'] ?? json['readingTimeMinutes']),
      knowledgeScore:
          _double(json['knowledge_score'] ?? json['knowledgeScore']),
      importanceScore:
          _double(json['importance_score'] ?? json['importanceScore'], 50),
      version: _int(json['version'], 1),
      syncStatus: json['sync_status'] as String? ??
          json['syncStatus'] as String? ??
          'pending',
      createdAt: _date(json['created_at'] ?? json['createdAt']),
      updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
      outgoingNoteIds:
          _strings(json['outgoing_note_ids'] ?? json['outgoingNoteIds']),
      incomingNoteIds:
          _strings(json['incoming_note_ids'] ?? json['incomingNoteIds']));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'noteType': noteType,
        'summary': summary,
        'blocks': blocks.map((block) => block.toJson()).toList(),
        'folderId': folderId,
        'workspace': workspace,
        'projectId': projectId,
        'tags': tags,
        'color': color,
        'icon': icon,
        'pinned': pinned,
        'favorite': favorite,
        'archived': archived,
        'deleted': deleted,
        'wordCount': wordCount,
        'readingTimeMinutes': readingTimeMinutes,
        'knowledgeScore': knowledgeScore,
        'importanceScore': importanceScore,
        'version': version,
        'syncStatus': syncStatus,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'outgoingNoteIds': outgoingNoteIds,
        'incomingNoteIds': incomingNoteIds
      };
}

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;
double _double(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
List<String> _strings(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => item is String
        ? item
        : item is Map<String, dynamic>
            ? item['name'] as String? ?? ''
            : '')
    .where((item) => item.isNotEmpty)
    .toList();
