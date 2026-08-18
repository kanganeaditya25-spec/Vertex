const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db/database');

const router = express.Router();

// Get all library items
router.get('/', (req, res) => {
  const { category, search, tag } = req.query;
  let query = 'SELECT * FROM library_items WHERE 1=1';
  const params = [];

  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }
  if (search) {
    query += ' AND (title LIKE ? OR description LIKE ? OR url LIKE ?)';
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (tag) {
    query += ' AND tags LIKE ?';
    params.push(`%${tag}%`);
  }

  query += ' ORDER BY created_at DESC';
  res.json(db.prepare(query).all(...params));
});

// Get single item
router.get('/:id', (req, res) => {
  const item = db.prepare('SELECT * FROM library_items WHERE id = ?').get(req.params.id);
  if (!item) return res.status(404).json({ error: 'Item not found' });
  res.json(item);
});

// Create item
router.post('/', (req, res) => {
  const { title, url, description, category, tags } = req.body;

  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Title is required' });
  }

  const id = uuidv4();
  const tagsJson = JSON.stringify(tags || []);

  db.prepare(`
    INSERT INTO library_items (id, title, url, description, category, tags)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, title.trim(), url || '', description || '', category || 'project', tagsJson);

  const item = db.prepare('SELECT * FROM library_items WHERE id = ?').get(id);
  res.status(201).json(item);
});

// Update item
router.put('/:id', (req, res) => {
  const item = db.prepare('SELECT * FROM library_items WHERE id = ?').get(req.params.id);
  if (!item) return res.status(404).json({ error: 'Item not found' });

  const { title, url, description, category, tags } = req.body;
  const tagsJson = tags ? JSON.stringify(tags) : item.tags;

  db.prepare(`
    UPDATE library_items SET 
      title = ?, url = ?, description = ?, category = ?, tags = ?,
      updated_at = datetime('now')
    WHERE id = ?
  `).run(
    title || item.title, url ?? item.url,
    description ?? item.description, category || item.category,
    tagsJson, req.params.id
  );

  const updated = db.prepare('SELECT * FROM library_items WHERE id = ?').get(req.params.id);
  res.json(updated);
});

// Delete item
router.delete('/:id', (req, res) => {
  const item = db.prepare('SELECT * FROM library_items WHERE id = ?').get(req.params.id);
  if (!item) return res.status(404).json({ error: 'Item not found' });

  db.prepare('DELETE FROM library_items WHERE id = ?').run(req.params.id);
  res.json({ success: true });
});

module.exports = router;
