const { db } = require('../db/database');

function getGoalTaskStats(goalId) {
  const stats = db.prepare(`
    SELECT
      COUNT(*) AS total,
      SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS completed,
      SUM(CASE WHEN status != 'done' THEN 1 ELSE 0 END) AS pending
    FROM tasks
    WHERE goal_id = ?
  `).get(goalId);

  return {
    total: Number(stats.total || 0),
    completed: Number(stats.completed || 0),
    pending: Number(stats.pending || 0)
  };
}

function syncGoalProgress(goalId) {
  if (!goalId) return null;

  const goal = db.prepare('SELECT * FROM goals WHERE id = ?').get(goalId);
  if (!goal) return null;

  const taskStats = getGoalTaskStats(goalId);
  if (taskStats.total === 0) return goal;

  const progress = Math.round((taskStats.completed / taskStats.total) * 100);
  const status = goal.status === 'paused'
    ? 'paused'
    : progress === 100
      ? 'completed'
      : 'active';

  db.prepare(`
    UPDATE goals
    SET progress = ?, status = ?, updated_at = datetime('now')
    WHERE id = ?
  `).run(progress, status, goalId);

  return db.prepare('SELECT * FROM goals WHERE id = ?').get(goalId);
}

function withTaskStats(goal) {
  const taskStats = getGoalTaskStats(goal.id);
  return {
    ...goal,
    linked_task_count: taskStats.total,
    completed_task_count: taskStats.completed,
    pending_task_count: taskStats.pending
  };
}

module.exports = { getGoalTaskStats, syncGoalProgress, withTaskStats };
