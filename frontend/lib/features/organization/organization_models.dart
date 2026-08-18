import 'dart:ui';

class WorkspaceModel {
  const WorkspaceModel(
      {required this.id,
      required this.name,
      this.description = '',
      this.icon = 'workspaces',
      this.coverImage,
      this.ownerId,
      this.color = '#4F46E5',
      this.favorite = false,
      this.archived = false,
      this.aiContext = '',
      this.settings = const {},
      this.createdAt,
      this.updatedAt});
  final String id;
  final String name;
  final String description;
  final String icon;
  final String? coverImage;
  final String? ownerId;
  final String color;
  final bool favorite;
  final bool archived;
  final String aiContext;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Color get accentColor => _color(color, const Color(0xFF4F46E5));
  WorkspaceModel copyWith(
          {String? name,
          String? description,
          bool? favorite,
          bool? archived}) =>
      WorkspaceModel(
          id: id,
          name: name ?? this.name,
          description: description ?? this.description,
          icon: icon,
          coverImage: coverImage,
          ownerId: ownerId,
          color: color,
          favorite: favorite ?? this.favorite,
          archived: archived ?? this.archived,
          aiContext: aiContext,
          settings: settings,
          createdAt: createdAt,
          updatedAt: updatedAt);
  factory WorkspaceModel.fromJson(Map<String, dynamic> json) => WorkspaceModel(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Workspace'}',
      description: '${json['description'] ?? ''}',
      icon: '${json['icon'] ?? 'workspaces'}',
      coverImage:
          json['cover_image'] as String? ?? json['coverImage'] as String?,
      ownerId: json['owner_id'] as String? ?? json['ownerId'] as String?,
      color: '${json['color'] ?? '#4F46E5'}',
      favorite: json['favorite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      aiContext: '${json['ai_context'] ?? json['aiContext'] ?? ''}',
      settings: (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: _date(json['created_at'] ?? json['createdAt']),
      updatedAt: _date(json['updated_at'] ?? json['updatedAt']));
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'cover_image': coverImage,
        'owner_id': ownerId,
        'color': color,
        'favorite': favorite,
        'archived': archived,
        'ai_context': aiContext,
        'settings': settings,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String()
      };
}

class ProjectModel {
  const ProjectModel(
      {required this.id,
      required this.workspaceId,
      required this.name,
      this.description = '',
      this.cover,
      this.icon = 'folder_special',
      this.color = '#0F766E',
      this.status = 'planning',
      this.priority = 'medium',
      this.startDate,
      this.deadline,
      this.estimatedMinutes = 0,
      this.budget,
      this.progress = 0,
      this.tags = const [],
      this.category = 'general',
      this.linkedGoalIds = const [],
      this.linkedTaskIds = const [],
      this.linkedNoteIds = const [],
      this.linkedEventIds = const [],
      this.linkedAssetIds = const [],
      this.linkedReminderIds = const [],
      this.statusOptions = const [],
      this.favorite = false,
      this.archived = false,
      this.locked = false,
      this.aiSummary = '',
      this.createdAt,
      this.updatedAt});
  final String id;
  final String workspaceId;
  final String name;
  final String description;
  final String? cover;
  final String icon;
  final String color;
  final String status;
  final String priority;
  final DateTime? startDate;
  final DateTime? deadline;
  final int estimatedMinutes;
  final double? budget;
  final double progress;
  final List<String> tags;
  final String category;
  final List<String> linkedGoalIds;
  final List<String> linkedTaskIds;
  final List<String> linkedNoteIds;
  final List<String> linkedEventIds;
  final List<String> linkedAssetIds;
  final List<String> linkedReminderIds;
  final List<String> statusOptions;
  final bool favorite;
  final bool archived;
  final bool locked;
  final String aiSummary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Color get accentColor => _color(color, const Color(0xFF0F766E));
  ProjectModel copyWith(
          {String? name,
          String? description,
          String? status,
          String? priority,
          double? progress,
          DateTime? deadline,
          bool? favorite,
          bool? archived}) =>
      ProjectModel(
          id: id,
          workspaceId: workspaceId,
          name: name ?? this.name,
          description: description ?? this.description,
          cover: cover,
          icon: icon,
          color: color,
          status: status ?? this.status,
          priority: priority ?? this.priority,
          startDate: startDate,
          deadline: deadline ?? this.deadline,
          estimatedMinutes: estimatedMinutes,
          budget: budget,
          progress: progress ?? this.progress,
          tags: tags,
          category: category,
          linkedGoalIds: linkedGoalIds,
          linkedTaskIds: linkedTaskIds,
          linkedNoteIds: linkedNoteIds,
          linkedEventIds: linkedEventIds,
          linkedAssetIds: linkedAssetIds,
          linkedReminderIds: linkedReminderIds,
          statusOptions: statusOptions,
          favorite: favorite ?? this.favorite,
          archived: archived ?? this.archived,
          locked: locked,
          aiSummary: aiSummary,
          createdAt: createdAt,
          updatedAt: updatedAt);
  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
      id: '${json['id'] ?? ''}',
      workspaceId: '${json['workspace_id'] ?? json['workspaceId'] ?? ''}',
      name: '${json['name'] ?? 'Project'}',
      description: '${json['description'] ?? ''}',
      cover: json['cover'] as String?,
      icon: '${json['icon'] ?? 'folder_special'}',
      color: '${json['color'] ?? '#0F766E'}',
      status: '${json['status'] ?? 'planning'}',
      priority: '${json['priority'] ?? 'medium'}',
      startDate: _date(json['start_date'] ?? json['startDate']),
      deadline: _date(json['deadline']),
      estimatedMinutes:
          _int(json['estimated_minutes'] ?? json['estimatedMinutes']),
      budget: json['budget'] is num
          ? (json['budget'] as num).toDouble()
          : double.tryParse('${json['budget']}'),
      progress: _double(json['progress']),
      tags: _strings(json['tags']),
      category: '${json['category'] ?? 'general'}',
      linkedGoalIds: _strings(json['linked_goal_ids'] ?? json['linkedGoalIds']),
      linkedTaskIds: _strings(json['linked_task_ids'] ?? json['linkedTaskIds']),
      linkedNoteIds: _strings(json['linked_note_ids'] ?? json['linkedNoteIds']),
      linkedEventIds:
          _strings(json['linked_event_ids'] ?? json['linkedEventIds']),
      linkedAssetIds:
          _strings(json['linked_asset_ids'] ?? json['linkedAssetIds']),
      linkedReminderIds:
          _strings(json['linked_reminder_ids'] ?? json['linkedReminderIds']),
      statusOptions: _strings(json['status_options'] ?? json['statusOptions']),
      favorite: json['favorite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
      aiSummary: '${json['ai_summary'] ?? json['aiSummary'] ?? ''}',
      createdAt: _date(json['created_at'] ?? json['createdAt']),
      updatedAt: _date(json['updated_at'] ?? json['updatedAt']));
  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'name': name,
        'description': description,
        'cover': cover,
        'icon': icon,
        'color': color,
        'status': status,
        'priority': priority,
        'start_date': startDate?.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'estimated_minutes': estimatedMinutes,
        'budget': budget,
        'progress': progress,
        'tags': tags,
        'category': category,
        'linked_goal_ids': linkedGoalIds,
        'linked_task_ids': linkedTaskIds,
        'linked_note_ids': linkedNoteIds,
        'linked_event_ids': linkedEventIds,
        'linked_asset_ids': linkedAssetIds,
        'linked_reminder_ids': linkedReminderIds,
        'status_options': statusOptions,
        'favorite': favorite,
        'archived': archived,
        'locked': locked,
        'ai_summary': aiSummary,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String()
      };
}

class GoalModel {
  const GoalModel(
      {required this.id,
      required this.title,
      this.workspaceId,
      this.description = '',
      this.goalType = 'weekly',
      this.targetDate,
      this.progress = 0,
      this.priority = 'medium',
      this.category = 'general',
      this.linkedProjectIds = const [],
      this.archived = false});
  final String id;
  final String title;
  final String? workspaceId;
  final String description;
  final String goalType;
  final DateTime? targetDate;
  final double progress;
  final String priority;
  final String category;
  final List<String> linkedProjectIds;
  final bool archived;
  GoalModel copyWith(
          {String? title,
          double? progress,
          DateTime? targetDate,
          bool? archived}) =>
      GoalModel(
          id: id,
          title: title ?? this.title,
          workspaceId: workspaceId,
          description: description,
          goalType: goalType,
          targetDate: targetDate ?? this.targetDate,
          progress: progress ?? this.progress,
          priority: priority,
          category: category,
          linkedProjectIds: linkedProjectIds,
          archived: archived ?? this.archived);
  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Goal'}',
      workspaceId:
          json['workspace_id'] as String? ?? json['workspaceId'] as String?,
      description: '${json['description'] ?? ''}',
      goalType: '${json['goal_type'] ?? json['goalType'] ?? 'weekly'}',
      targetDate: _date(json['target_date'] ?? json['targetDate']),
      progress: _double(json['progress']),
      priority: '${json['priority'] ?? 'medium'}',
      category: '${json['category'] ?? 'general'}',
      linkedProjectIds:
          _strings(json['linked_project_ids'] ?? json['linkedProjectIds']),
      archived: json['archived'] as bool? ?? false);
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'workspace_id': workspaceId,
        'description': description,
        'goal_type': goalType,
        'target_date': targetDate?.toIso8601String(),
        'progress': progress,
        'priority': priority,
        'category': category,
        'linked_project_ids': linkedProjectIds,
        'archived': archived
      };
}

class MilestoneModel {
  const MilestoneModel(
      {required this.id,
      required this.projectId,
      required this.name,
      this.deadline,
      this.progress = 0,
      this.taskIds = const [],
      this.dependencyIds = const [],
      this.completed = false});
  final String id;
  final String projectId;
  final String name;
  final DateTime? deadline;
  final double progress;
  final List<String> taskIds;
  final List<String> dependencyIds;
  final bool completed;
  MilestoneModel copyWith(
          {String? name,
          double? progress,
          bool? completed,
          DateTime? deadline}) =>
      MilestoneModel(
          id: id,
          projectId: projectId,
          name: name ?? this.name,
          deadline: deadline ?? this.deadline,
          progress: progress ?? this.progress,
          taskIds: taskIds,
          dependencyIds: dependencyIds,
          completed: completed ?? this.completed);
  factory MilestoneModel.fromJson(Map<String, dynamic> json) => MilestoneModel(
      id: '${json['id'] ?? ''}',
      projectId: '${json['project_id'] ?? json['projectId'] ?? ''}',
      name: '${json['name'] ?? 'Milestone'}',
      deadline: _date(json['deadline']),
      progress: _double(json['progress']),
      taskIds: _strings(json['task_ids'] ?? json['taskIds']),
      dependencyIds: _strings(json['dependency_ids'] ?? json['dependencyIds']),
      completed: json['completed'] as bool? ?? false);
  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'deadline': deadline?.toIso8601String(),
        'progress': progress,
        'task_ids': taskIds,
        'dependency_ids': dependencyIds,
        'completed': completed
      };
}

class ProjectTemplateModel {
  const ProjectTemplateModel(
      {required this.id,
      required this.name,
      required this.category,
      this.description = '',
      this.milestoneNames = const []});
  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> milestoneNames;
  factory ProjectTemplateModel.fromJson(Map<String, dynamic> json) =>
      ProjectTemplateModel(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? 'Template'}',
          category: '${json['category'] ?? 'general'}',
          description: '${json['description'] ?? ''}',
          milestoneNames:
              _strings(json['milestone_names'] ?? json['milestoneNames']));
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value');
double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
List<String> _strings(dynamic value) =>
    (value as List<dynamic>? ?? const []).map((item) => '$item').toList();
Color _color(String value, Color fallback) {
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
