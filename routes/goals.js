const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db/database');
const { syncGoalProgress, withTaskStats } = require('../services/goals');

const router = express.Router();

// Get all goals
router.get('/', (req, res) => {
  const { status } = req.query;
  let query = 'SELECT * FROM goals';
  const params = [];

  if (status) {
    query += ' WHERE status = ?';
    params.push(status);
  }

  query += ' ORDER BY created_at DESC';
  const goals = db.prepare(query).all(...params).map(withTaskStats);
  res.json(goals);
});

// Get single goal
router.get('/:id', (req, res) => {
  const goal = db.prepare('SELECT * FROM goals WHERE id = ?').get(req.params.id);
  if (!goal) return res.status(404).json({ error: 'Goal not found' });
  res.json(withTaskStats(goal));
});

// Create goal
router.post('/', (req, res) => {
  const { title, description, target_date, progress } = req.body;

  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Title is required' });
  }

  const id = uuidv4();
  db.prepare(`
    INSERT INTO goals (id, title, description, target_date, progress)
    VALUES (?, ?, ?, ?, ?)
  `).run(id, title.trim(), description || '', target_date || null, progress || 0);

  const goal = db.prepare('SELECT * FROM goals WHERE id = ?').get(id);
  res.status(201).json(withTaskStats(goal));
});

// Update goal
router.put('/:id', (req, res) => {
  const goal = db.prepare('SELECT * FROM goals WHERE id = ?').get(req.params.id);
  if (!goal) return res.status(404).json({ error: 'Goal not found' });

  const { title, description, target_date, status, progress, progress_note } = req.body;

  // Append progress note if provided
  let progressNotes = [];
  try {
    progressNotes = JSON.parse(goal.progress_notes || '[]');
  } catch (e) {
    progressNotes = [];
  }

  if (progress_note) {
    progressNotes.push({
      date: new Date().toISOString(),
      note: progress_note,
      progress: progress ?? goal.progress
    });
  }

  db.prepare(`
    UPDATE goals SET 
      title = ?, description = ?, target_date = ?, 
      status = ?, progress = ?, progress_notes = ?,
      updated_at = datetime('now')
    WHERE id = ?
  `).run(
    title || goal.title, description ?? goal.description,
    target_date ?? goal.target_date, status || goal.status,
    progress ?? goal.progress, JSON.stringify(progressNotes),
    req.params.id
  );

  syncGoalProgress(req.params.id);
  const updated = db.prepare('SELECT * FROM goals WHERE id = ?').get(req.params.id);
  res.json(withTaskStats(updated));
});

// Delete goal
router.delete('/:id', (req, res) => {
  const goal = db.prepare('SELECT * FROM goals WHERE id = ?').get(req.params.id);
  if (!goal) return res.status(404).json({ error: 'Goal not found' });

  db.prepare('UPDATE tasks SET goal_id = NULL WHERE goal_id = ?').run(req.params.id);
  db.prepare('DELETE FROM goals WHERE id = ?').run(req.params.id);
  res.json({ success: true });
});

module.exports = router;
