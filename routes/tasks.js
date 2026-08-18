const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db/database');
const { syncGoalProgress } = require('../services/goals');

const router = express.Router();

// Configure multer for file uploads
// Vercel's deployment bundle is read-only. Attachments on Vercel are temporary.
const uploadsDir = process.env.VERCEL === '1'
  ? path.join('/tmp', 'productivity-dashboard', 'uploads')
  : path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|pdf|doc|docx|txt|zip|mp4|mp3|webp|svg/;
    const ext = allowed.test(path.extname(file.originalname).toLowerCase());
    cb(null, ext);
  }
});

// Get all tasks (with optional filters)
router.get('/', (req, res) => {
  const { status, category, date, search } = req.query;
  let query = 'SELECT * FROM tasks WHERE 1=1';
  const params = [];

  if (status) {
    query += ' AND status = ?';
    params.push(status);
  }
  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }
  if (date) {
    query += ' AND due_date = ?';
    params.push(date);
  }
  if (search) {
    query += ' AND (title LIKE ? OR description LIKE ?)';
    params.push(`%${search}%`, `%${search}%`);
  }

  query += ' ORDER BY sort_order ASC, created_at DESC';

  const tasks = db.prepare(query).all(...params);

  // Attach assets to each task
  const assetStmt = db.prepare('SELECT * FROM task_assets WHERE task_id = ?');
  const goalStmt = db.prepare('SELECT id, title, status, progress FROM goals WHERE id = ?');
  tasks.forEach(task => {
    task.assets = assetStmt.all(task.id);
    task.goal = task.goal_id ? goalStmt.get(task.goal_id) || null : null;
  });

  res.json(tasks);
});

// Get single task
router.get('/:id', (req, res) => {
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  if (!task) return res.status(404).json({ error: 'Task not found' });

  task.assets = db.prepare('SELECT * FROM task_assets WHERE task_id = ?').all(task.id);
  task.goal = task.goal_id ? db.prepare('SELECT id, title, status, progress FROM goals WHERE id = ?').get(task.goal_id) || null : null;
  res.json(task);
});

// Create task
router.post('/', (req, res) => {
  const { title, description, status, priority, category, due_date, reminder_time, goal_id } = req.body;

  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Title is required' });
  }

  const normalizedGoalId = goal_id || null;
  if (normalizedGoalId && !db.prepare('SELECT id FROM goals WHERE id = ?').get(normalizedGoalId)) {
    return res.status(400).json({ error: 'Selected goal was not found' });
  }

  const id = uuidv4();
  db.prepare(`
    INSERT INTO tasks (id, title, description, status, priority, category, due_date, reminder_time, goal_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(id, title.trim(), description || '', status || 'todo', priority || 'medium', category || 'general', due_date || null, reminder_time || null, normalizedGoalId);

  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
  task.assets = [];
  task.goal = normalizedGoalId ? db.prepare('SELECT id, title, status, progress FROM goals WHERE id = ?').get(normalizedGoalId) || null : null;
  res.status(201).json(task);
});

// Update task
router.put('/:id', (req, res) => {
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  if (!task) return res.status(404).json({ error: 'Task not found' });

  const { title, description, status, priority, category, due_date, reminder_time, sort_order } = req.body;
  const hasGoalId = Object.prototype.hasOwnProperty.call(req.body, 'goal_id');
  const nextGoalId = hasGoalId ? (req.body.goal_id || null) : task.goal_id;

  if (nextGoalId && !db.prepare('SELECT id FROM goals WHERE id = ?').get(nextGoalId)) {
    return res.status(400).json({ error: 'Selected goal was not found' });
  }

  let completed_at = task.completed_at;
  if (status === 'done' && task.status !== 'done') {
    completed_at = new Date().toISOString();
  } else if (status !== 'done') {
    completed_at = null;
  }

  db.prepare(`
    UPDATE tasks SET 
      title = ?, description = ?, status = ?, priority = ?, 
      category = ?, due_date = ?, reminder_time = ?, 
      sort_order = ?, completed_at = ?, goal_id = ?
    WHERE id = ?
  `).run(
    title || task.title, description ?? task.description, 
    status || task.status, priority || task.priority,
    category || task.category, due_date ?? task.due_date, 
    reminder_time ?? task.reminder_time,
    sort_order ?? task.sort_order, completed_at, nextGoalId,
    req.params.id
  );

  if (task.goal_id && task.goal_id !== nextGoalId) syncGoalProgress(task.goal_id);
  if (nextGoalId) syncGoalProgress(nextGoalId);

  const updated = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  updated.assets = db.prepare('SELECT * FROM task_assets WHERE task_id = ?').all(updated.id);
  updated.goal = updated.goal_id ? db.prepare('SELECT id, title, status, progress FROM goals WHERE id = ?').get(updated.goal_id) || null : null;
  res.json(updated);
});

// Toggle task completion
router.patch('/:id/toggle', (req, res) => {
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  if (!task) return res.status(404).json({ error: 'Task not found' });

  const newStatus = task.status === 'done' ? 'todo' : 'done';
  const completed_at = newStatus === 'done' ? new Date().toISOString() : null;

  db.prepare('UPDATE tasks SET status = ?, completed_at = ? WHERE id = ?')
    .run(newStatus, completed_at, req.params.id);

  if (task.goal_id) syncGoalProgress(task.goal_id);

  const updated = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  updated.assets = db.prepare('SELECT * FROM task_assets WHERE task_id = ?').all(updated.id);
  updated.goal = updated.goal_id ? db.prepare('SELECT id, title, status, progress FROM goals WHERE id = ?').get(updated.goal_id) || null : null;
  res.json(updated);
});

// Delete task
router.delete('/:id', (req, res) => {
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  if (!task) return res.status(404).json({ error: 'Task not found' });

  // Delete associated files
  const assets = db.prepare('SELECT * FROM task_assets WHERE task_id = ?').all(req.params.id);
  assets.forEach(asset => {
    const filePath = path.join(uploadsDir, path.basename(asset.file_path));
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  });

  const linkedGoalId = task.goal_id;
  db.prepare('DELETE FROM tasks WHERE id = ?').run(req.params.id);
  if (linkedGoalId) syncGoalProgress(linkedGoalId);
  res.json({ success: true });
});

// Upload asset to task
router.post('/:id/assets', upload.single('file'), (req, res) => {
  const task = db.prepare('SELECT * FROM tasks WHERE id = ?').get(req.params.id);
  if (!task) return res.status(404).json({ error: 'Task not found' });

  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

  const assetId = uuidv4();
  db.prepare(`
    INSERT INTO task_assets (id, task_id, file_name, file_path, file_type, file_size)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(assetId, req.params.id, req.file.originalname, req.file.filename, req.file.mimetype, req.file.size);

  const asset = db.prepare('SELECT * FROM task_assets WHERE id = ?').get(assetId);
  res.status(201).json(asset);
});

// Delete asset
router.delete('/:id/assets/:assetId', (req, res) => {
  const asset = db.prepare('SELECT * FROM task_assets WHERE id = ? AND task_id = ?')
    .get(req.params.assetId, req.params.id);
  if (!asset) return res.status(404).json({ error: 'Asset not found' });

  const filePath = path.join(uploadsDir, path.basename(asset.file_path));
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

  db.prepare('DELETE FROM task_assets WHERE id = ?').run(req.params.assetId);
  res.json({ success: true });
});

module.exports = router;
