class ReminderModel {
  ReminderModel({
    required this.id,
    required this.title,
    this.description = '',
    this.linkedModule = 'system',
    this.linkedItemId = '',
    this.workspaceId = '',
    this.projectId = '',
    this.goalId = '',
    this.category = 'general',
    this.priority = 3,
    this.triggerType = 'time',
    this.triggerAt,
    this.nextTriggerAt,
    this.repeatRule = const {},
    this.notificationType = 'local',
    this.sound = true,
    this.vibration = true,
    this.icon = 'notifications',
    this.color = '#2563EB',
    this.aiGenerated = false,
    this.status = 'scheduled',
    this.locationContext = '',
    this.locked = false,
    this.hidden = false,
    this.snoozedCount = 0,
    this.completedAt,
    this.lastTriggeredAt,
    this.sourceRule = '',
    this.metadata = const {},
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : createdAt =
            createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        modifiedAt =
            modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final String id;
  final String title;
  final String description;
  final String linkedModule;
  final String linkedItemId;
  final String workspaceId;
  final String projectId;
  final String goalId;
  final String category;
  final int priority;
  final String triggerType;
  final DateTime? triggerAt;
  final DateTime? nextTriggerAt;
  final Map<String, dynamic> repeatRule;
  final String notificationType;
  final bool sound;
  final bool vibration;
  final String icon;
  final String color;
  final bool aiGenerated;
  final String status;
  final String locationContext;
  final bool locked;
  final bool hidden;
  final int snoozedCount;
  final DateTime? completedAt;
  final DateTime? lastTriggeredAt;
  final String sourceRule;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime modifiedAt;

  bool get isActive => status == 'scheduled' || status == 'triggered';
  bool get isOverdue =>
      isActive &&
      nextTriggerAt != null &&
      nextTriggerAt!.isBefore(DateTime.now());

  ReminderModel copyWith({
    String? title,
    String? description,
    String? category,
    int? priority,
    String? triggerType,
    DateTime? triggerAt,
    DateTime? nextTriggerAt,
    Map<String, dynamic>? repeatRule,
    String? notificationType,
    bool? sound,
    bool? vibration,
    String? icon,
    String? color,
    bool? aiGenerated,
    String? status,
    String? locationContext,
    bool? locked,
    bool? hidden,
    int? snoozedCount,
    DateTime? completedAt,
    String? sourceRule,
    Map<String, dynamic>? metadata,
  }) =>
      ReminderModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        linkedModule: linkedModule,
        linkedItemId: linkedItemId,
        workspaceId: workspaceId,
        projectId: projectId,
        goalId: goalId,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        triggerType: triggerType ?? this.triggerType,
        triggerAt: triggerAt ?? this.triggerAt,
        nextTriggerAt: nextTriggerAt ?? this.nextTriggerAt,
        repeatRule: repeatRule ?? this.repeatRule,
        notificationType: notificationType ?? this.notificationType,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        aiGenerated: aiGenerated ?? this.aiGenerated,
        status: status ?? this.status,
        locationContext: locationContext ?? this.locationContext,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
        snoozedCount: snoozedCount ?? this.snoozedCount,
        completedAt: completedAt ?? this.completedAt,
        lastTriggeredAt: lastTriggeredAt,
        sourceRule: sourceRule ?? this.sourceRule,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

  factory ReminderModel.fromJson(Map<String, dynamic> json) => ReminderModel(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        description: '${json['description'] ?? ''}',
        linkedModule:
            '${json['linked_module'] ?? json['linkedModule'] ?? 'system'}',
        linkedItemId: '${json['linked_item_id'] ?? json['linkedItemId'] ?? ''}',
        workspaceId: '${json['workspace_id'] ?? json['workspaceId'] ?? ''}',
        projectId: '${json['project_id'] ?? json['projectId'] ?? ''}',
        goalId: '${json['goal_id'] ?? json['goalId'] ?? ''}',
        category: '${json['category'] ?? 'general'}',
        priority: _int(json['priority'], 3),
        triggerType: '${json['trigger_type'] ?? json['triggerType'] ?? 'time'}',
        triggerAt: _date(json['trigger_at'] ?? json['triggerAt']),
        nextTriggerAt: _date(json['next_trigger_at'] ?? json['nextTriggerAt']),
        repeatRule: _map(json['repeat_rule'] ?? json['repeatRule']),
        notificationType:
            '${json['notification_type'] ?? json['notificationType'] ?? 'local'}',
        sound: json['sound'] as bool? ?? true,
        vibration: json['vibration'] as bool? ?? true,
        icon: '${json['icon'] ?? 'notifications'}',
        color: '${json['color'] ?? '#2563EB'}',
        aiGenerated: json['ai_generated'] as bool? ??
            json['aiGenerated'] as bool? ??
            false,
        status: '${json['status'] ?? 'scheduled'}',
        locationContext:
            '${json['location_context'] ?? json['locationContext'] ?? ''}',
        locked: json['locked'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        snoozedCount: _int(json['snoozed_count'] ?? json['snoozedCount']),
        completedAt: _date(json['completed_at'] ?? json['completedAt']),
        lastTriggeredAt:
            _date(json['last_triggered_at'] ?? json['lastTriggeredAt']),
        sourceRule: '${json['source_rule'] ?? json['sourceRule'] ?? ''}',
        metadata: _map(json['metadata']),
        createdAt: _date(json['created_at'] ?? json['createdAt']),
        modifiedAt: _date(json['modified_at'] ?? json['modifiedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'linkedModule': linkedModule,
        'linkedItemId': linkedItemId,
        'workspaceId': workspaceId,
        'projectId': projectId,
        'goalId': goalId,
        'category': category,
        'priority': priority,
        'triggerType': triggerType,
        'triggerAt': triggerAt?.toIso8601String(),
        'nextTriggerAt': nextTriggerAt?.toIso8601String(),
        'repeatRule': repeatRule,
        'notificationType': notificationType,
        'sound': sound,
        'vibration': vibration,
        'icon': icon,
        'color': color,
        'aiGenerated': aiGenerated,
        'status': status,
        'locationContext': locationContext,
        'locked': locked,
        'hidden': hidden,
        'snoozedCount': snoozedCount,
        'completedAt': completedAt?.toIso8601String(),
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
        'sourceRule': sourceRule,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };
}

class ReminderHistoryModel {
  const ReminderHistoryModel(
      {required this.id,
      required this.reminderId,
      required this.action,
      required this.occurredAt,
      this.fromAt,
      this.toAt,
      this.reason = '',
      this.metadata = const {}});
  final String id;
  final String reminderId;
  final String action;
  final DateTime occurredAt;
  final DateTime? fromAt;
  final DateTime? toAt;
  final String reason;
  final Map<String, dynamic> metadata;

  factory ReminderHistoryModel.fromJson(Map<String, dynamic> json) =>
      ReminderHistoryModel(
          id: '${json['id'] ?? ''}',
          reminderId: '${json['reminder_id'] ?? json['reminderId'] ?? ''}',
          action: '${json['action'] ?? ''}',
          occurredAt: _date(json['occurred_at'] ?? json['occurredAt']) ??
              DateTime.now(),
          fromAt: _date(json['from_at'] ?? json['fromAt']),
          toAt: _date(json['to_at'] ?? json['toAt']),
          reason: '${json['reason'] ?? ''}',
          metadata: _map(json['metadata']));
}

class ReminderPreferencesModel {
  const ReminderPreferencesModel(
      {this.localEnabled = true,
      this.silentMode = false,
      this.quietHoursEnabled = false,
      this.quietStartMinutes = 1320,
      this.quietEndMinutes = 420,
      this.focusSessionsEnabled = true,
      this.sleepScheduleEnabled = false,
      this.workHoursEnabled = false,
      this.workStartMinutes = 540,
      this.workEndMinutes = 1020,
      this.calendarAwareness = true,
      this.metadata = const {}});
  final bool localEnabled;
  final bool silentMode;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final bool focusSessionsEnabled;
  final bool sleepScheduleEnabled;
  final bool workHoursEnabled;
  final int workStartMinutes;
  final int workEndMinutes;
  final bool calendarAwareness;
  final Map<String, dynamic> metadata;

  ReminderPreferencesModel copyWith(
          {bool? localEnabled,
          bool? silentMode,
          bool? quietHoursEnabled,
          int? quietStartMinutes,
          int? quietEndMinutes,
          bool? focusSessionsEnabled,
          bool? sleepScheduleEnabled,
          bool? workHoursEnabled,
          int? workStartMinutes,
          int? workEndMinutes,
          bool? calendarAwareness}) =>
      ReminderPreferencesModel(
          localEnabled: localEnabled ?? this.localEnabled,
          silentMode: silentMode ?? this.silentMode,
          quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
          quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
          quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
          focusSessionsEnabled:
              focusSessionsEnabled ?? this.focusSessionsEnabled,
          sleepScheduleEnabled:
              sleepScheduleEnabled ?? this.sleepScheduleEnabled,
          workHoursEnabled: workHoursEnabled ?? this.workHoursEnabled,
          workStartMinutes: workStartMinutes ?? this.workStartMinutes,
          workEndMinutes: workEndMinutes ?? this.workEndMinutes,
          calendarAwareness: calendarAwareness ?? this.calendarAwareness,
          metadata: metadata);

  factory ReminderPreferencesModel.fromJson(Map<String, dynamic> json) =>
      ReminderPreferencesModel(
          localEnabled: json['local_enabled'] as bool? ??
              json['localEnabled'] as bool? ??
              true,
          silentMode: json['silent_mode'] as bool? ??
              json['silentMode'] as bool? ??
              false,
          quietHoursEnabled: json['quiet_hours_enabled'] as bool? ??
              json['quietHoursEnabled'] as bool? ??
              false,
          quietStartMinutes: _int(
              json['quiet_start_minutes'] ?? json['quietStartMinutes'], 1320),
          quietEndMinutes:
              _int(json['quiet_end_minutes'] ?? json['quietEndMinutes'], 420),
          focusSessionsEnabled: json['focus_sessions_enabled'] as bool? ??
              json['focusSessionsEnabled'] as bool? ??
              true,
          sleepScheduleEnabled: json['sleep_schedule_enabled'] as bool? ??
              json['sleepScheduleEnabled'] as bool? ??
              false,
          workHoursEnabled: json['work_hours_enabled'] as bool? ??
              json['workHoursEnabled'] as bool? ??
              false,
          workStartMinutes:
              _int(json['work_start_minutes'] ?? json['workStartMinutes'], 540),
          workEndMinutes:
              _int(json['work_end_minutes'] ?? json['workEndMinutes'], 1020),
          calendarAwareness: json['calendar_awareness'] as bool? ??
              json['calendarAwareness'] as bool? ??
              true,
          metadata: _map(json['metadata']));

  Map<String, dynamic> toJson() => {
        'localEnabled': localEnabled,
        'silentMode': silentMode,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartMinutes': quietStartMinutes,
        'quietEndMinutes': quietEndMinutes,
        'focusSessionsEnabled': focusSessionsEnabled,
        'sleepScheduleEnabled': sleepScheduleEnabled,
        'workHoursEnabled': workHoursEnabled,
        'workStartMinutes': workStartMinutes,
        'workEndMinutes': workEndMinutes,
        'calendarAwareness': calendarAwareness,
        'metadata': metadata
      };
}

class ReminderStatsModel {
  const ReminderStatsModel(
      {this.total = 0,
      this.active = 0,
      this.completed = 0,
      this.dismissed = 0,
      this.overdue = 0,
      this.snoozeRate = 0,
      this.completionRate = 0,
      this.missedRate = 0,
      this.bestReminderHour});
  final int total;
  final int active;
  final int completed;
  final int dismissed;
  final int overdue;
  final double snoozeRate;
  final double completionRate;
  final double missedRate;
  final int? bestReminderHour;
}

class SmartSuggestionModel {
  const SmartSuggestionModel(
      {required this.reminderId,
      required this.recommendation,
      required this.reason,
      this.suggestedTriggerAt,
      this.confidence = 0});
  final String reminderId;
  final String recommendation;
  final String reason;
  final DateTime? suggestedTriggerAt;
  final double confidence;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
