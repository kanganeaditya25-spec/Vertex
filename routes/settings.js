const express = require('express');
const { db, getSetting, setSetting } = require('../db/database');

const router = express.Router();

// Get settings
router.get('/', (req, res) => {
  const geminiKey = getSetting('gemini_api_key');
  const morningHour = getSetting('morning_reminder_hour') || process.env.MORNING_REMINDER_HOUR || '8';
  const eveningHour = getSetting('evening_reminder_hour') || process.env.EVENING_REMINDER_HOUR || '20';
  const notificationsEnabled = getSetting('notifications_enabled') || 'true';

  res.json({
    geminiKeySet: !!geminiKey,
    morningReminderHour: parseInt(morningHour),
    eveningReminderHour: parseInt(eveningHour),
    notificationsEnabled: notificationsEnabled === 'true'
  });
});

// Update settings
router.put('/', (req, res) => {
  const { geminiKey, morningReminderHour, eveningReminderHour, notificationsEnabled } = req.body;

  if (geminiKey !== undefined) {
    setSetting('gemini_api_key', geminiKey);
  }
  if (morningReminderHour !== undefined) {
    setSetting('morning_reminder_hour', String(morningReminderHour));
  }
  if (eveningReminderHour !== undefined) {
    setSetting('evening_reminder_hour', String(eveningReminderHour));
  }
  if (notificationsEnabled !== undefined) {
    setSetting('notifications_enabled', String(notificationsEnabled));
  }

  res.json({ success: true });
});

// Export all data
router.get('/export', (req, res) => {
  const tasks = db.prepare('SELECT * FROM tasks').all();
  const assets = db.prepare('SELECT * FROM task_assets').all();
  const library = db.prepare('SELECT * FROM library_items').all();
  const goals = db.prepare('SELECT * FROM goals').all();

  res.json({
    exportDate: new Date().toISOString(),
    tasks,
    taskAssets: assets,
    libraryItems: library,
    goals
  });
});

module.exports = router;
