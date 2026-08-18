const path = require('path');
const { DatabaseSync } = require('node:sqlite');

const databasePath = path.join(__dirname, '..', 'data', 'productivity.db');
const db = new DatabaseSync(databasePath);
const rows = db.prepare("SELECT key, value FROM settings WHERE key IN ('morning_reminder_hour', 'evening_reminder_hour', 'notifications_enabled') ORDER BY key").all();
console.log(JSON.stringify(rows));
db.close();
