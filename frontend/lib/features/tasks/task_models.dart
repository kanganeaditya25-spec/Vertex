class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.completed = false,
    this.position = 0,
    this.completedAt,
  });

  final String id;
  final String text;
  final bool completed;
  final int position;
  final DateTime? completedAt;

  ChecklistItem copyWith(
          {bool? completed,
          String? text,
          int? position,
          DateTime? completedAt}) =>
      ChecklistItem(
        id: id,
        text: text ?? this.text,
        completed: completed ?? this.completed,
        position: position ?? this.position,
        completedAt: completedAt ?? this.completedAt,
      );

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        position: (json['position'] as num?)?.toInt() ?? 0,
        completedAt: _parseDate(json['completed_at'] ?? json['completedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'completed': completed,
        'position': position,
        'completedAt': completedAt?.toIso8601String(),
      };
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'inbox',
    this.priority = 'medium',
    this.category = 'general',
    this.project,
    this.workspace,
    this.estimatedMinutes = 0,
    this.actualMinutes = 0,
    this.deadline,
    this.reminderAt,
    this.repeatRule,
    this.location,
    this.energyLevel = 'medium',
    this.difficulty = 'normal',
    this.importanceScore = 50,
    this.aiScore = 0,
    this.riskScore = 0,
    this.completionPercent = 0,
    this.goalId,
    this.parentTaskId,
    this.tags = const [],
    this.checklist = const [],
    this.pinned = false,
    this.favorite = false,
    this.privateTask = false,
    this.shared = false,
    this.aiGenerated = false,
    this.syncStatus = 'pending',
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.archivedAt,
    this.deletedAt,
    this.explanation = '',
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String category;
  final String? project;
  final String? workspace;
  final int estimatedMinutes;
  final int actualMinutes;
  final DateTime? deadline;
  final DateTime? reminderAt;
  final String? repeatRule;
  final String? location;
  final String energyLevel;
  final String difficulty;
  final double importanceScore;
  final double aiScore;
  final double riskScore;
  final double completionPercent;
  final String? goalId;
  final String? parentTaskId;
  final List<String> tags;
  final List<ChecklistItem> checklist;
  final bool pinned;
  final bool favorite;
  final bool privateTask;
  final bool shared;
  final bool aiGenerated;
  final String syncStatus;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final String explanation;

  bool get isCompleted => status == 'completed' || status == 'done';
  bool get isArchived => status == 'archived';
  bool get isDeleted => status == 'deleted' || deletedAt != null;
  int get checklistCompleted =>
      checklist.where((item) => item.completed).length;
  double get checklistProgress => checklist.isEmpty
      ? completionPercent
      : checklistCompleted / checklist.length * 100;

  TaskModel copyWith({
    String? title,
    String? description,
    String? status,
    String? priority,
    String? category,
    String? project,
    String? workspace,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? deadline,
    DateTime? reminderAt,
    String? repeatRule,
    String? location,
    String? energyLevel,
    String? difficulty,
    double? importanceScore,
    double? aiScore,
    double? riskScore,
    double? completionPercent,
    String? goalId,
    String? parentTaskId,
    List<String>? tags,
    List<ChecklistItem>? checklist,
    bool? pinned,
    bool? favorite,
    bool? privateTask,
    bool? shared,
    bool? aiGenerated,
    String? syncStatus,
    int? version,
    DateTime? completedAt,
    DateTime? archivedAt,
    DateTime? deletedAt,
    String? explanation,
    bool clearCompletedAt = false,
    bool clearArchivedAt = false,
    bool clearDeletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TaskModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        category: category ?? this.category,
        project: project ?? this.project,
        workspace: workspace ?? this.workspace,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        actualMinutes: actualMinutes ?? this.actualMinutes,
        deadline: deadline ?? this.deadline,
        reminderAt: reminderAt ?? this.reminderAt,
        repeatRule: repeatRule ?? this.repeatRule,
        location: location ?? this.location,
        energyLevel: energyLevel ?? this.energyLevel,
        difficulty: difficulty ?? this.difficulty,
        importanceScore: importanceScore ?? this.importanceScore,
        aiScore: aiScore ?? this.aiScore,
        riskScore: riskScore ?? this.riskScore,
        completionPercent: completionPercent ?? this.completionPercent,
        goalId: goalId ?? this.goalId,
        parentTaskId: parentTaskId ?? this.parentTaskId,
        tags: tags ?? this.tags,
        checklist: checklist ?? this.checklist,
        pinned: pinned ?? this.pinned,
        favorite: favorite ?? this.favorite,
        privateTask: privateTask ?? this.privateTask,
        shared: shared ?? this.shared,
        aiGenerated: aiGenerated ?? this.aiGenerated,
        syncStatus: syncStatus ?? this.syncStatus,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
        archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
        deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
        explanation: explanation ?? this.explanation,
      );

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'inbox',
        priority: json['priority'] as String? ?? 'medium',
        category: json['category'] as String? ?? 'general',
        project: json['project'] as String?,
        workspace: json['workspace'] as String?,
        estimatedMinutes:
            _int(json['estimated_minutes'] ?? json['estimatedMinutes']),
        actualMinutes: _int(json['actual_minutes'] ?? json['actualMinutes']),
        deadline:
            _parseDate(json['deadline'] ?? json['due_date'] ?? json['dueAt']),
        reminderAt: _parseDate(json['reminder_at'] ?? json['reminderAt']),
        repeatRule:
            json['repeat_rule'] as String? ?? json['repeatRule'] as String?,
        location: json['location'] as String?,
        energyLevel: json['energy_level'] as String? ??
            json['energyLevel'] as String? ??
            'medium',
        difficulty: json['difficulty'] as String? ?? 'normal',
        importanceScore:
            _double(json['importance_score'] ?? json['importanceScore'], 50),
        aiScore: _double(json['ai_score'] ?? json['aiScore']),
        riskScore: _double(json['risk_score'] ?? json['riskScore']),
        completionPercent:
            _double(json['completion_percent'] ?? json['completionPercent']),
        goalId: json['goal_id'] as String? ?? json['goalId'] as String?,
        parentTaskId: json['parent_task_id'] as String? ??
            json['parentTaskId'] as String?,
        tags: _tags(json['tags']),
        checklist: (json['checklist'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChecklistItem.fromJson)
            .toList(),
        pinned: json['pinned'] as bool? ?? false,
        favorite: json['favorite'] as bool? ?? false,
        privateTask:
            json['private'] as bool? ?? json['privateTask'] as bool? ?? false,
        shared: json['shared'] as bool? ?? false,
        aiGenerated: json['ai_generated'] as bool? ??
            json['aiGenerated'] as bool? ??
            false,
        syncStatus: json['sync_status'] as String? ??
            json['syncStatus'] as String? ??
            'pending',
        version: _int(json['version'], 1),
        createdAt: _parseDate(json['created_at'] ?? json['createdAt']) ??
            DateTime.now(),
        updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']) ??
            DateTime.now(),
        completedAt: _parseDate(json['completed_at'] ?? json['completedAt']),
        archivedAt: _parseDate(json['archived_at'] ?? json['archivedAt']),
        deletedAt: _parseDate(json['deleted_at'] ?? json['deletedAt']),
        explanation: json['explanation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'category': category,
        'project': project,
        'workspace': workspace,
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'deadline': deadline?.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'repeatRule': repeatRule,
        'location': location,
        'energyLevel': energyLevel,
        'difficulty': difficulty,
        'importanceScore': importanceScore,
        'aiScore': aiScore,
        'riskScore': riskScore,
        'completionPercent': completionPercent,
        'goalId': goalId,
        'parentTaskId': parentTaskId,
        'tags': tags,
        'checklist': checklist.map((item) => item.toJson()).toList(),
        'pinned': pinned,
        'favorite': favorite,
        'privateTask': privateTask,
        'shared': shared,
        'aiGenerated': aiGenerated,
        'syncStatus': syncStatus,
        'version': version,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'archivedAt': archivedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'explanation': explanation,
      };
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;
double _double(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

List<String> _tags(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => item is String
        ? item
        : item is Map<String, dynamic>
            ? item['name'] as String? ?? ''
            : '')
    .where((item) => item.isNotEmpty)
    .toList();
