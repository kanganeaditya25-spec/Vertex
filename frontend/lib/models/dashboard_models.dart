class TaskSummary {
  const TaskSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueAt,
    this.estimatedMinutes = 0,
    this.goalTitle,
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final DateTime? dueAt;
  final int estimatedMinutes;
  final String? goalTitle;

  bool get isCompleted => status == 'done' || status == 'completed';

  factory TaskSummary.fromJson(Map<String, dynamic> json) => TaskSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? 'todo',
        priority: json['priority'] as String? ?? 'medium',
        dueAt: json['dueAt'] == null ? null : DateTime.tryParse(json['dueAt'] as String),
        estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 0,
        goalTitle: json['goalTitle'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        'priority': priority,
        'dueAt': dueAt?.toIso8601String(),
        'estimatedMinutes': estimatedMinutes,
        'goalTitle': goalTitle,
      };
}

class GoalSummary {
  const GoalSummary({
    required this.id,
    required this.title,
    required this.progress,
    this.targetDate,
    this.linkedTaskCount = 0,
    this.completedTaskCount = 0,
  });

  final String id;
  final String title;
  final double progress;
  final DateTime? targetDate;
  final int linkedTaskCount;
  final int completedTaskCount;

  factory GoalSummary.fromJson(Map<String, dynamic> json) => GoalSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        targetDate: json['targetDate'] == null ? null : DateTime.tryParse(json['targetDate'] as String),
        linkedTaskCount: (json['linkedTaskCount'] as num?)?.toInt() ?? 0,
        completedTaskCount: (json['completedTaskCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'progress': progress,
        'targetDate': targetDate?.toIso8601String(),
        'linkedTaskCount': linkedTaskCount,
        'completedTaskCount': completedTaskCount,
      };
}

class CalendarEvent {
  const CalendarEvent({required this.id, required this.title, required this.startsAt, this.durationMinutes = 60});

  final String id;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        startsAt: DateTime.tryParse(json['startsAt'] as String? ?? '') ?? DateTime.now(),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startsAt': startsAt.toIso8601String(),
        'durationMinutes': durationMinutes,
      };
}

class ProjectSummary {
  const ProjectSummary({required this.id, required this.name, required this.progress, this.blocked = false});

  final String id;
  final String name;
  final double progress;
  final bool blocked;

  factory ProjectSummary.fromJson(Map<String, dynamic> json) => ProjectSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        blocked: json['blocked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'progress': progress, 'blocked': blocked};
}

class HabitSummary {
  const HabitSummary({required this.id, required this.name, this.completed = false, this.streak = 0});

  final String id;
  final String name;
  final bool completed;
  final int streak;

  factory HabitSummary.fromJson(Map<String, dynamic> json) => HabitSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'completed': completed, 'streak': streak};
}

class NoteSummary {
  const NoteSummary({required this.id, required this.title, required this.updatedAt, this.pinned = false});

  final String id;
  final String title;
  final DateTime updatedAt;
  final bool pinned;

  factory NoteSummary.fromJson(Map<String, dynamic> json) => NoteSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        pinned: json['pinned'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'updatedAt': updatedAt.toIso8601String(), 'pinned': pinned};
}

class FocusSummary {
  const FocusSummary({
    this.isRunning = false,
    this.isPaused = false,
    this.elapsedSeconds = 0,
    this.todaySeconds = 0,
    this.longestSessionSeconds = 0,
    this.distractionCount = 0,
  });

  final bool isRunning;
  final bool isPaused;
  final int elapsedSeconds;
  final int todaySeconds;
  final int longestSessionSeconds;
  final int distractionCount;

  FocusSummary copyWith({
    bool? isRunning,
    bool? isPaused,
    int? elapsedSeconds,
    int? todaySeconds,
    int? longestSessionSeconds,
    int? distractionCount,
  }) => FocusSummary(
        isRunning: isRunning ?? this.isRunning,
        isPaused: isPaused ?? this.isPaused,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        todaySeconds: todaySeconds ?? this.todaySeconds,
        longestSessionSeconds: longestSessionSeconds ?? this.longestSessionSeconds,
        distractionCount: distractionCount ?? this.distractionCount,
      );

  factory FocusSummary.fromJson(Map<String, dynamic> json) => FocusSummary(
        isRunning: json['isRunning'] as bool? ?? false,
        isPaused: json['isPaused'] as bool? ?? false,
        elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
        todaySeconds: (json['todaySeconds'] as num?)?.toInt() ?? 0,
        longestSessionSeconds: (json['longestSessionSeconds'] as num?)?.toInt() ?? 0,
        distractionCount: (json['distractionCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'isRunning': isRunning,
        'isPaused': isPaused,
        'elapsedSeconds': elapsedSeconds,
        'todaySeconds': todaySeconds,
        'longestSessionSeconds': longestSessionSeconds,
        'distractionCount': distractionCount,
      };
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.userName,
    required this.tasks,
    required this.goals,
    required this.events,
    required this.projects,
    required this.habits,
    required this.notes,
    required this.focus,
    required this.lastUpdated,
  });

  final String userName;
  final List<TaskSummary> tasks;
  final List<GoalSummary> goals;
  final List<CalendarEvent> events;
  final List<ProjectSummary> projects;
  final List<HabitSummary> habits;
  final List<NoteSummary> notes;
  final FocusSummary focus;
  final DateTime lastUpdated;

  factory DashboardSnapshot.empty() => DashboardSnapshot(
        userName: 'there',
        tasks: const [],
        goals: const [],
        events: const [],
        projects: const [],
        habits: const [],
        notes: const [],
        focus: const FocusSummary(),
        lastUpdated: DateTime.now(),
      );

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) => DashboardSnapshot(
        userName: json['userName'] as String? ?? 'there',
        tasks: (json['tasks'] as List<dynamic>? ?? const []).map((item) => TaskSummary.fromJson(item as Map<String, dynamic>)).toList(),
        goals: (json['goals'] as List<dynamic>? ?? const []).map((item) => GoalSummary.fromJson(item as Map<String, dynamic>)).toList(),
        events: (json['events'] as List<dynamic>? ?? const []).map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>)).toList(),
        projects: (json['projects'] as List<dynamic>? ?? const []).map((item) => ProjectSummary.fromJson(item as Map<String, dynamic>)).toList(),
        habits: (json['habits'] as List<dynamic>? ?? const []).map((item) => HabitSummary.fromJson(item as Map<String, dynamic>)).toList(),
        notes: (json['notes'] as List<dynamic>? ?? const []).map((item) => NoteSummary.fromJson(item as Map<String, dynamic>)).toList(),
        focus: FocusSummary.fromJson((json['focus'] as Map<String, dynamic>?) ?? const {}),
        lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'goals': goals.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
        'projects': projects.map((item) => item.toJson()).toList(),
        'habits': habits.map((item) => item.toJson()).toList(),
        'notes': notes.map((item) => item.toJson()).toList(),
        'focus': focus.toJson(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  DashboardSnapshot copyWith({FocusSummary? focus, DateTime? lastUpdated}) => DashboardSnapshot(
        userName: userName,
        tasks: tasks,
        goals: goals,
        events: events,
        projects: projects,
        habits: habits,
        notes: notes,
        focus: focus ?? this.focus,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

class DashboardPreferences {
  const DashboardPreferences({required this.visibleWidgets, required this.pinnedWidgets});

  final List<String> visibleWidgets;
  final List<String> pinnedWidgets;

  factory DashboardPreferences.defaults() => const DashboardPreferences(
        visibleWidgets: [
          'today_overview',
          'ai_priority',
          'focus',
          'calendar',
          'recent_notes',
          'projects',
          'habits',
          'analytics',
        ],
        pinnedWidgets: ['today_overview', 'focus'],
      );

  factory DashboardPreferences.fromJson(Map<String, dynamic> json) => DashboardPreferences(
        visibleWidgets: List<String>.from(json['visibleWidgets'] as List<dynamic>? ?? DashboardPreferences.defaults().visibleWidgets),
        pinnedWidgets: List<String>.from(json['pinnedWidgets'] as List<dynamic>? ?? DashboardPreferences.defaults().pinnedWidgets),
      );

  Map<String, dynamic> toJson() => {'visibleWidgets': visibleWidgets, 'pinnedWidgets': pinnedWidgets};
}
