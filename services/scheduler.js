const cron = require('node-cron');
const { db } = require('../db/database');
const { broadcastNotification } = require('./push');

let jobs = [];

function startScheduler() {
  // Clear any existing jobs
  jobs.forEach(job => job.stop());
  jobs = [];

  const morningHour = process.env.MORNING_REMINDER_HOUR || 8;
  const eveningHour = process.env.EVENING_REMINDER_HOUR || 20;

  // Morning reminder — Today's tasks summary
  const morningJob = cron.schedule(`0 ${morningHour} * * *`, async () => {
    console.log('[Scheduler] Morning reminder triggered');
    const today = new Date().toISOString().split('T')[0];
    const tasks = db.prepare(
      "SELECT * FROM tasks WHERE due_date = ? AND status != 'done'"
    ).all(today);

    const payload = {
      title: '☀️ Good Morning!',
      body: tasks.length > 0
        ? `You have ${tasks.length} task${tasks.length > 1 ? 's' : ''} due today. Let's get productive!`
        : "No tasks due today. Plan something great!",
      url: '/#tasks',
      tag: 'morning-reminder'
    };

    await broadcastNotification(payload);
  });
  jobs.push(morningJob);

  // Evening reminder — Plan tomorrow's tasks
  const eveningJob = cron.schedule(`0 ${eveningHour} * * *`, async () => {
    console.log('[Scheduler] Evening reminder triggered');
    const today = new Date().toISOString().split('T')[0];
    const completedToday = db.prepare(
      "SELECT COUNT(*) as count FROM tasks WHERE completed_at LIKE ? AND status = 'done'"
    ).get(today + '%');

    const pendingCount = db.prepare(
      "SELECT COUNT(*) as count FROM tasks WHERE status != 'done'"
    ).get();

    const payload = {
      title: '🌙 Time to Plan Tomorrow',
      body: `You completed ${completedToday.count} tasks today. ${pendingCount.count} pending. Plan your tomorrow now!`,
      url: '/#tasks',
      tag: 'evening-reminder'
    };

    await broadcastNotification(payload);
  });
  jobs.push(eveningJob);

  // Per-minute check for task-specific reminders
  const reminderJob = cron.schedule('* * * * *', async () => {
    const now = new Date();
    const currentTime = now.toTimeString().slice(0, 5); // "HH:MM"
    const today = now.toISOString().split('T')[0];

    const tasksWithReminder = db.prepare(
      "SELECT * FROM tasks WHERE reminder_time = ? AND due_date = ? AND status != 'done'"
    ).all(currentTime, today);

    for (const task of tasksWithReminder) {
      const payload = {
        title: `⏰ Reminder: ${task.title}`,
        body: task.description || `This task is due today (${task.priority} priority)`,
        url: '/#tasks',
        tag: `task-reminder-${task.id}`
      };
      await broadcastNotification(payload);

      // Clear the reminder so it doesn't fire again
      db.prepare('UPDATE tasks SET reminder_time = NULL WHERE id = ?').run(task.id);
    }
  });
  jobs.push(reminderJob);

  console.log(`[Scheduler] Started — Morning: ${morningHour}:00, Evening: ${eveningHour}:00, Task reminders: every minute`);
}

function stopScheduler() {
  jobs.forEach(job => job.stop());
  jobs = [];
  console.log('[Scheduler] Stopped');
}

module.exports = { startScheduler, stopScheduler };
