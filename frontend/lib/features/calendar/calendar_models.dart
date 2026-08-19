class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.description = '',
    this.eventType = 'custom',
    this.category = 'general',
    this.priority = 'medium',
    this.status = 'scheduled',
    this.timezone = 'UTC',
    this.location,
    this.color,
    this.icon,
    this.taskId,
    this.projectId,
    this.goalId,
    this.notes = '',
    this.estimatedMinutes = 0,
    this.actualMinutes = 0,
    this.focusType,
    this.energyLevel = 'medium',
    this.travelBufferMinutes = 0,
    this.preparationBufferMinutes = 0,
    this.cleanupBufferMinutes = 0,
    this.aiScheduled = false,
    this.locked = false,
    this.flexible = true,
    this.recurring = false,
    this.allDay = false,
    this.completed = false,
    this.version = 1,
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String eventType;
  final String category;
  final String priority;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
  final String? location;
  final String? color;
  final String? icon;
  final String? taskId;
  final String? projectId;
  final String? goalId;
  final String notes;
  final int estimatedMinutes;
  final int actualMinutes;
  final String? focusType;
  final String energyLevel;
  final int travelBufferMinutes;
  final int preparationBufferMinutes;
  final int cleanupBufferMinutes;
  final bool aiScheduled;
  final bool locked;
  final bool flexible;
  final bool recurring;
  final bool allDay;
  final bool completed;
  final int version;
  final String syncStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration get duration => endAt.difference(startAt);
  bool get isCancelled => status == 'cancelled';
  bool get isArchived => status == 'archived';

  CalendarEvent copyWith({
    String? title,
    String? description,
    String? eventType,
    String? category,
    String? priority,
    String? status,
    DateTime? startAt,
    DateTime? endAt,
    String? location,
    String? color,
    String? notes,
    int? estimatedMinutes,
    int? actualMinutes,
    String? energyLevel,
    bool? aiScheduled,
    bool? locked,
    bool? flexible,
    bool? completed,
    String? syncStatus,
    int? version,
  }) =>
      CalendarEvent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        eventType: eventType ?? this.eventType,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        timezone: timezone,
        location: location ?? this.location,
        color: color ?? this.color,
        icon: icon,
        taskId: taskId,
        projectId: projectId,
        goalId: goalId,
        notes: notes ?? this.notes,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        actualMinutes: actualMinutes ?? this.actualMinutes,
        focusType: focusType,
        energyLevel: energyLevel ?? this.energyLevel,
        travelBufferMinutes: travelBufferMinutes,
        preparationBufferMinutes: preparationBufferMinutes,
        cleanupBufferMinutes: cleanupBufferMinutes,
        aiScheduled: aiScheduled ?? this.aiScheduled,
        locked: locked ?? this.locked,
        flexible: flexible ?? this.flexible,
        recurring: recurring,
        allDay: allDay,
        completed: completed ?? this.completed,
        version: version ?? this.version,
        syncStatus: syncStatus ?? this.syncStatus,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        eventType: json['event_type'] as String? ??
            json['eventType'] as String? ??
            'custom',
        category: json['category'] as String? ?? 'general',
        priority: json['priority'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'scheduled',
        startAt: _date(json['start_at'] ?? json['startAt']) ?? DateTime.now(),
        endAt: _date(json['end_at'] ?? json['endAt']) ??
            DateTime.now().add(const Duration(minutes: 30)),
        timezone: json['timezone'] as String? ?? 'UTC',
        location: json['location'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        taskId: json['task_id'] as String? ?? json['taskId'] as String?,
        projectId:
            json['project_id'] as String? ?? json['projectId'] as String?,
        goalId: json['goal_id'] as String? ?? json['goalId'] as String?,
        notes: json['notes'] as String? ?? '',
        estimatedMinutes:
            _integer(json['estimated_minutes'] ?? json['estimatedMinutes']),
        actualMinutes:
            _integer(json['actual_minutes'] ?? json['actualMinutes']),
        focusType:
            json['focus_type'] as String? ?? json['focusType'] as String?,
        energyLevel: json['energy_level'] as String? ??
            json['energyLevel'] as String? ??
            'medium',
        travelBufferMinutes: _integer(
            json['travel_buffer_minutes'] ?? json['travelBufferMinutes']),
        preparationBufferMinutes: _integer(json['preparation_buffer_minutes'] ??
            json['preparationBufferMinutes']),
        cleanupBufferMinutes: _integer(
            json['cleanup_buffer_minutes'] ?? json['cleanupBufferMinutes']),
        aiScheduled: json['ai_scheduled'] as bool? ??
            json['aiScheduled'] as bool? ??
            false,
        locked: json['locked'] as bool? ?? false,
        flexible: json['flexible'] as bool? ?? true,
        recurring: json['recurring'] as bool? ?? false,
        allDay: json['all_day'] as bool? ?? json['allDay'] as bool? ?? false,
        completed: json['completed'] as bool? ?? false,
        version: _integer(json['version'], 1),
        syncStatus: json['sync_status'] as String? ??
            json['syncStatus'] as String? ??
            'pending',
        createdAt: _date(json['created_at'] ?? json['createdAt']),
        updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'eventType': eventType,
        'category': category,
        'priority': priority,
        'status': status,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'timezone': timezone,
        'location': location,
        'color': color,
        'icon': icon,
        'taskId': taskId,
        'projectId': projectId,
        'goalId': goalId,
        'notes': notes,
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'focusType': focusType,
        'energyLevel': energyLevel,
        'travelBufferMinutes': travelBufferMinutes,
        'preparationBufferMinutes': preparationBufferMinutes,
        'cleanupBufferMinutes': cleanupBufferMinutes,
        'aiScheduled': aiScheduled,
        'locked': locked,
        'flexible': flexible,
        'recurring': recurring,
        'allDay': allDay,
        'completed': completed,
        'version': version,
        'syncStatus': syncStatus,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

class CalendarPreferences {
  const CalendarPreferences(
      {this.defaultView = 'week',
      this.workStartMinute = 540,
      this.workEndMinute = 1020,
      this.firstDayOfWeek = 1,
      this.density = 'comfortable',
      this.reducedMotion = false,
      this.highContrast = false});
  final String defaultView;
  final int workStartMinute;
  final int workEndMinute;
  final int firstDayOfWeek;
  final String density;
  final bool reducedMotion;
  final bool highContrast;

  CalendarPreferences copyWith(
          {String? defaultView,
          int? workStartMinute,
          int? workEndMinute,
          int? firstDayOfWeek,
          String? density,
          bool? reducedMotion,
          bool? highContrast}) =>
      CalendarPreferences(
          defaultView: defaultView ?? this.defaultView,
          workStartMinute: workStartMinute ?? this.workStartMinute,
          workEndMinute: workEndMinute ?? this.workEndMinute,
          firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
          density: density ?? this.density,
          reducedMotion: reducedMotion ?? this.reducedMotion,
          highContrast: highContrast ?? this.highContrast);

  factory CalendarPreferences.fromJson(Map<String, dynamic> json) =>
      CalendarPreferences(
          defaultView: json['default_view'] as String? ??
              json['defaultView'] as String? ??
              'agenda',
          workStartMinute: _integer(
              json['work_start_minute'] ?? json['workStartMinute'], 540),
          workEndMinute:
              _integer(json['work_end_minute'] ?? json['workEndMinute'], 1020),
          firstDayOfWeek:
              _integer(json['first_day_of_week'] ?? json['firstDayOfWeek'], 1),
          density: json['density'] as String? ?? 'comfortable',
          reducedMotion: json['reduced_motion'] as bool? ??
              json['reducedMotion'] as bool? ??
              false,
          highContrast: json['high_contrast'] as bool? ??
              json['highContrast'] as bool? ??
              false);

  Map<String, dynamic> toJson() => {
        'defaultView': defaultView,
        'workStartMinute': workStartMinute,
        'workEndMinute': workEndMinute,
        'firstDayOfWeek': firstDayOfWeek,
        'density': density,
        'reducedMotion': reducedMotion,
        'highContrast': highContrast
      };
}

class CalendarConflict {
  const CalendarConflict(
      {required this.conflictType,
      required this.severity,
      required this.eventIds,
      required this.message,
      required this.suggestedResolution});
  final String conflictType;
  final String severity;
  final List<String> eventIds;
  final String message;
  final String suggestedResolution;

  factory CalendarConflict.fromJson(Map<String, dynamic> json) =>
      CalendarConflict(
          conflictType: json['conflict_type'] as String? ?? 'overlap',
          severity: json['severity'] as String? ?? 'moderate',
          eventIds: (json['event_ids'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
          message: json['message'] as String? ?? '',
          suggestedResolution: json['suggested_resolution'] as String? ?? '');
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;
