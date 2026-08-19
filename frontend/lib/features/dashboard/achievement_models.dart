class TrophyDefinition {
  const TrophyDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.threshold,
  });

  final String id;
  final String title;
  final String description;
  final int threshold;
}

const trophyDefinitions = <TrophyDefinition>[
  TrophyDefinition(
      id: 'first_step',
      title: 'First Step',
      description: 'Complete your first meaningful task.',
      threshold: 1),
  TrophyDefinition(
      id: 'steady_week',
      title: 'Steady Week',
      description: 'Maintain a three-day completion streak.',
      threshold: 3),
  TrophyDefinition(
      id: 'ten_tasks',
      title: 'Momentum Builder',
      description: 'Complete ten meaningful tasks.',
      threshold: 10),
  TrophyDefinition(
      id: 'focused_month',
      title: 'Focused Month',
      description: 'Complete work on fifteen different days.',
      threshold: 15),
  TrophyDefinition(
      id: 'level_five',
      title: 'Deep Practice',
      description: 'Reach 500 XP through completed work.',
      threshold: 500),
];

class AchievementProfile {
  const AchievementProfile({
    this.xp = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletedTasks = 0,
    this.focusDays = 0,
    this.lastCompletionDate,
    this.completionDates = const [],
    this.completedTaskIds = const [],
    this.trophies = const [],
  });

  final int xp;
  final int currentStreak;
  final int bestStreak;
  final int totalCompletedTasks;
  final int focusDays;
  final DateTime? lastCompletionDate;
  final List<String> completionDates;
  final List<String> completedTaskIds;
  final List<String> trophies;

  int get level => xp ~/ 100 + 1;
  int get levelXp => xp % 100;
  int get xpToNextLevel => 100 - levelXp;
  double get levelProgress => levelXp / 100;

  AchievementProfile copyWith({
    int? xp,
    int? currentStreak,
    int? bestStreak,
    int? totalCompletedTasks,
    int? focusDays,
    DateTime? lastCompletionDate,
    List<String>? completionDates,
    List<String>? completedTaskIds,
    List<String>? trophies,
  }) =>
      AchievementProfile(
        xp: xp ?? this.xp,
        currentStreak: currentStreak ?? this.currentStreak,
        bestStreak: bestStreak ?? this.bestStreak,
        totalCompletedTasks: totalCompletedTasks ?? this.totalCompletedTasks,
        focusDays: focusDays ?? this.focusDays,
        lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
        completionDates: completionDates ?? this.completionDates,
        completedTaskIds: completedTaskIds ?? this.completedTaskIds,
        trophies: trophies ?? this.trophies,
      );

  factory AchievementProfile.fromJson(Map<String, dynamic> json) =>
      AchievementProfile(
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
        totalCompletedTasks:
            (json['totalCompletedTasks'] as num?)?.toInt() ?? 0,
        focusDays: (json['focusDays'] as num?)?.toInt() ?? 0,
        lastCompletionDate: _parseDate(json['lastCompletionDate']),
        completionDates: (json['completionDates'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        completedTaskIds: (json['completedTaskIds'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        trophies: (json['trophies'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'totalCompletedTasks': totalCompletedTasks,
        'focusDays': focusDays,
        'lastCompletionDate': lastCompletionDate?.toIso8601String(),
        'completionDates': completionDates,
        'completedTaskIds': completedTaskIds,
        'trophies': trophies,
      };
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String achievementDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
