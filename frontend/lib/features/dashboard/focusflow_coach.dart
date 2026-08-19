import '../../models/dashboard_models.dart';

class MissionRecommendation {
  const MissionRecommendation({
    required this.task,
    required this.pendingCount,
    required this.estimatedMinutes,
    required this.overloaded,
    required this.message,
    required this.reason,
  });

  final TaskSummary? task;
  final int pendingCount;
  final int estimatedMinutes;
  final bool overloaded;
  final String message;
  final String reason;

  bool get hasMission => task != null;
}

class FocusFlowCoach {
  const FocusFlowCoach._();

  static MissionRecommendation recommend(
    DashboardSnapshot snapshot, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final pending = snapshot.tasks.where((task) => !task.isCompleted).toList();
    final estimatedMinutes = pending.fold<int>(
      0,
      (total, task) =>
          total + (task.estimatedMinutes > 0 ? task.estimatedMinutes : 25),
    );
    final overloaded = pending.length > 6 || estimatedMinutes > 240;
    pending.sort((left, right) => _compare(left, right, reference));

    if (pending.isEmpty) {
      return const MissionRecommendation(
        task: null,
        pendingCount: 0,
        estimatedMinutes: 0,
        overloaded: false,
        message:
            'Your task list is clear. Capture the next meaningful step or use this time for a focused review.',
        reason: 'No unfinished task needs attention right now.',
      );
    }

    final task = pending.first;
    final reason = _reason(task, reference);
    final message = overloaded
        ? 'You have more planned than a focused day can comfortably hold. Start with this one, then rebalance the rest.'
        : 'Start with this one meaningful step. Completing it moves your work forward without opening the whole backlog.';
    return MissionRecommendation(
      task: task,
      pendingCount: pending.length,
      estimatedMinutes: estimatedMinutes,
      overloaded: overloaded,
      message: message,
      reason: reason,
    );
  }

  static int _compare(TaskSummary left, TaskSummary right, DateTime now) {
    final leftOverdue = left.dueAt != null && left.dueAt!.isBefore(now);
    final rightOverdue = right.dueAt != null && right.dueAt!.isBefore(now);
    if (leftOverdue != rightOverdue) {
      return leftOverdue ? -1 : 1;
    }

    final dueComparison =
        (left.dueAt ?? DateTime(9999)).compareTo(right.dueAt ?? DateTime(9999));
    if (dueComparison != 0) {
      return dueComparison;
    }

    const priority = {'high': 0, 'medium': 1, 'low': 2};
    final priorityComparison =
        (priority[left.priority] ?? 1).compareTo(priority[right.priority] ?? 1);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final goalComparison = (right.goalTitle != null ? 0 : 1)
        .compareTo(left.goalTitle != null ? 0 : 1);
    if (goalComparison != 0) {
      return goalComparison;
    }
    return left.estimatedMinutes.compareTo(right.estimatedMinutes);
  }

  static String _reason(TaskSummary task, DateTime now) {
    if (task.dueAt != null && task.dueAt!.isBefore(now)) {
      return 'Overdue · recover this commitment first';
    }
    if (task.dueAt != null) {
      return 'Due ${task.dueAt!.month}/${task.dueAt!.day} · protect the deadline';
    }
    if (task.priority == 'high') {
      return 'High priority · meaningful progress comes before lower-impact work';
    }

    if (task.goalTitle != null) {
      return 'Supports ${task.goalTitle}';
    }
    return 'A clear next step to build momentum';
  }
}
