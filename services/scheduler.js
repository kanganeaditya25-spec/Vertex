const cron = require('node-cron');
const { db, getSetting } = require('../db/database');
const { broadcastNotification } = require('./push');

let jobs = [];
let lastMorningNotification = null;
let lastEveningNotification = null;

function getConfiguredHour(settingKey, envKey, fallback) {
  const rawValue = getSetting(settingKey) ?? process.env[envKey] ?? fallback;
  const hour = Number.parseInt(rawValue, 10);
  return Number.isInteger(hour) && hour >= 0 && hour <= 23 ? hour : fallback;
}

function notificationsEnabled() {
  const storedValue = getSetting('notifications_enabled');
  return storedValue === 'true';
}

function localDateKey(date = new Date()) {
  const offset = date.getTimezoneOffset() * 60 * 1000;
  return new Date(date.getTime() - offset).toISOString().split('T')[0];
}

async function sendMorningReminder(today) {
  const tasks = db.prepare(
    "SELECT * FROM tasks WHERE due_date = ? AND status != 'done'"
  ).all(today);

  await broadcastNotification({
    title: 'Good Morning!',
    body: tasks.length > 0
      ? `You have ${tasks.length} task${tasks.length > 1 ? 's' : ''} due today. Let's get productive!`
      : 'No tasks due today. Plan something great!',
    url: '/#tasks',
    tag: 'morning-reminder'
  });
}

async function sendEveningReminder(today) {
  const completedToday = db.prepare(
    "SELECT COUNT(*) as count FROM tasks WHERE completed_at LIKE ? AND status = 'done'"
  ).get(`${today}%`);

  const pendingCount = db.prepare(
    "SELECT COUNT(*) as count FROM tasks WHERE status != 'done'"
  ).get();

  await broadcastNotification({
    title: 'Time to Plan Tomorrow',
    body: `You completed ${completedToday.count} tasks today. ${pendingCount.count} pending. Plan your tomorrow now!`,
    url: '/#tasks',
    tag: 'evening-reminder'
  });
}

async function processScheduledNotifications() {
  const now = new Date();
  const today = localDateKey(now);
  const currentHour = now.getHours();
  const currentMinute = now.getMinutes();
  const enabled = notificationsEnabled();

  if (currentMinute === 0 && enabled) {
    const morningHour = getConfiguredHour('morning_reminder_hour', 'MORNING_REMINDER_HOUR', 8);
    if (currentHour === morningHour && lastMorningNotification !== today) {
      console.log('[Scheduler] Morning reminder triggered');
      await sendMorningReminder(today);
      lastMorningNotification = today;
    }

    const eveningHour = getConfiguredHour('evening_reminder_hour', 'EVENING_REMINDER_HOUR', 20);
    if (currentHour === eveningHour && lastEveningNotification !== today) {
      console.log('[Scheduler] Evening reminder triggered');
      await sendEveningReminder(today);
      lastEveningNotification = today;
    }
  }

  const currentTime = now.toTimeString().slice(0, 5);
  const tasksWithReminder = db.prepare(
    "SELECT * FROM tasks WHERE reminder_time = ? AND due_date = ? AND status != 'done'"
  ).all(currentTime, today);

  for (const task of tasksWithReminder) {
    if (enabled) {
      await broadcastNotification({
        title: `Reminder: ${task.title}`,
        body: task.description || `This task is due today (${task.priority} priority)`,
        url: '/#tasks',
        tag: `task-reminder-${task.id}`
      });
    }

    // Consume the reminder once its scheduled minute has arrived. When notifications
    // are disabled, this prevents a stale reminder from firing unexpectedly later.
    db.prepare('UPDATE tasks SET reminder_time = NULL WHERE id = ?').run(task.id);
  }
}

function startScheduler() {
  jobs.forEach(job => job.stop());
  jobs = [];
  lastMorningNotification = null;
  lastEveningNotification = null;

  // Read reminder hours and the notification flag on every tick so Settings changes
  // take effect without requiring a process restart.
  const notificationJob = cron.schedule('* * * * *', () => {
    processScheduledNotifications().catch(error => {
      console.error('[Scheduler] Notification processing failed:', error.message);
    });
  });
  jobs.push(notificationJob);

  console.log('[Scheduler] Started — settings-aware daily and task reminders run every minute');
}

function stopScheduler() {
  jobs.forEach(job => job.stop());
  jobs = [];
  console.log('[Scheduler] Stopped');
}

module.exports = { startScheduler, stopScheduler, processScheduledNotifications };
