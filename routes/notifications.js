const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db/database');
const { getPublicKey } = require('../services/push');

const router = express.Router();

// Get VAPID public key
router.get('/vapid-key', (req, res) => {
  const key = getPublicKey();
  res.json({ publicKey: key });
});

// Subscribe to push notifications
router.post('/subscribe', (req, res) => {
  const { subscription } = req.body;
  if (!subscription) {
    return res.status(400).json({ error: 'Subscription object required' });
  }

  const subStr = JSON.stringify(subscription);

  // Check if already subscribed
  const existing = db.prepare('SELECT * FROM push_subscriptions WHERE subscription = ?').get(subStr);
  if (existing) {
    return res.json({ success: true, message: 'Already subscribed' });
  }

  const id = uuidv4();
  db.prepare('INSERT INTO push_subscriptions (id, subscription) VALUES (?, ?)').run(id, subStr);

  res.json({ success: true });
});

// Unsubscribe
router.post('/unsubscribe', (req, res) => {
  const { subscription } = req.body;
  if (!subscription) {
    return res.status(400).json({ error: 'Subscription object required' });
  }

  const subStr = JSON.stringify(subscription);
  db.prepare('DELETE FROM push_subscriptions WHERE subscription = ?').run(subStr);

  res.json({ success: true });
});

module.exports = router;
