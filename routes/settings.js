const express = require('express');
const { db, getSetting, setSetting } = require('../db/database');

const router = express.Router();

function parseHour(value, fallback) {
  const hour = Number.parseInt(value, 10);
  return Number.isInteger(hour) && hour >= 0 && hour <= 23 ? hour : fallback;
}

// Get settings
router.get('/', (req, res) => {
  const geminiKey = getSetting('gemini_api_key');
  const morningHour = getSetting('morning_reminder_hour') ?? process.env.MORNING_REMINDER_HOUR ?? '8';
  const eveningHour = getSetting('evening_reminder_hour') ?? process.env.EVENING_REMINDER_HOUR ?? '20';
  const notificationsEnabled = getSetting('notifications_enabled') ?? 'false';

  res.json({
    geminiKeySet: !!geminiKey,
    morningReminderHour: parseHour(morningHour, 8),
    eveningReminderHour: parseHour(eveningHour, 20),
    notificationsEnabled: notificationsEnabled === 'true'
  });
});

// Update settings
router.put('/', (req, res) => {
  const { geminiKey, morningReminderHour, eveningReminderHour, notificationsEnabled } = req.body;

  if (geminiKey !== undefined) {
    if (typeof geminiKey !== 'string' || geminiKey.length > 4096) {
      return res.status(400).json({ error: 'Gemini API key must be a string of 4096 characters or fewer' });
    }
    setSetting('gemini_api_key', geminiKey.trim());
  }

  if (morningReminderHour !== undefined) {
    const hour = Number(morningReminderHour);
    if (!Number.isInteger(hour) || hour < 0 || hour > 23) {
      return res.status(400).json({ error: 'Morning reminder hour must be an integer from 0 to 23' });
    }
    setSetting('morning_reminder_hour', String(hour));
  }

  if (eveningReminderHour !== undefined) {
    const hour = Number(eveningReminderHour);
    if (!Number.isInteger(hour) || hour < 0 || hour > 23) {
      return res.status(400).json({ error: 'Evening reminder hour must be an integer from 0 to 23' });
    }
    setSetting('evening_reminder_hour', String(hour));
  }

  if (notificationsEnabled !== undefined) {
    if (typeof notificationsEnabled !== 'boolean') {
      return res.status(400).json({ error: 'notificationsEnabled must be a boolean' });
    }
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
