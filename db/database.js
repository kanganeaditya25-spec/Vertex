const { DatabaseSync } = require('node:sqlite');
const path = require('path');
const fs = require('fs');

// Vercel's deployment bundle is read-only. `/tmp` is writable there, but ephemeral.
const dataDir = process.env.VERCEL === '1'
  ? path.join('/tmp', 'productivity-dashboard', 'data')
  : path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'productivity.db');
const db = new DatabaseSync(dbPath);

// Enable WAL mode for better performance
db.exec('PRAGMA journal_mode = WAL');
db.exec('PRAGMA foreign_keys = ON');

// Create tables
db.exec(`
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    status TEXT DEFAULT 'todo' CHECK(status IN ('todo', 'in-progress', 'done')),
    priority TEXT DEFAULT 'medium' CHECK(priority IN ('low', 'medium', 'high')),
    category TEXT DEFAULT 'general',
    due_date TEXT,
    reminder_time TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    sort_order INTEGER DEFAULT 0,
    goal_id TEXT
  );

  CREATE TABLE IF NOT EXISTS task_assets (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_type TEXT DEFAULT '',
    file_size INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS library_items (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    url TEXT DEFAULT '',
    description TEXT DEFAULT '',
    category TEXT DEFAULT 'project' CHECK(category IN ('project', 'idea', 'resource')),
    tags TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    target_date TEXT,
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'completed', 'paused')),
    progress INTEGER DEFAULT 0 CHECK(progress >= 0 AND progress <= 100),
    progress_notes TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS push_subscriptions (
    id TEXT PRIMARY KEY,
    subscription TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
  CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
  CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
  CREATE INDEX IF NOT EXISTS idx_library_category ON library_items(category);
  CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
`);

// Backward-compatible migration for databases created before task-goal links.
const taskColumns = db.prepare('PRAGMA table_info(tasks)').all();
if (!taskColumns.some(column => column.name === 'goal_id')) {
  db.exec('ALTER TABLE tasks ADD COLUMN goal_id TEXT');
}
db.exec('CREATE INDEX IF NOT EXISTS idx_tasks_goal_id ON tasks(goal_id)');

// Helper functions
const getSetting = (key) => {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(key);
  return row ? row.value : null;
};

const setSetting = (key, value) => {
  db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)').run(key, value);
};

module.exports = { db, getSetting, setSetting };
