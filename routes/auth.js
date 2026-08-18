const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getSetting, setSetting } = require('../db/database');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';

// Check if PIN is set up
router.get('/status', (req, res) => {
  const pinHash = getSetting('pin_hash');
  res.json({ isSetup: !!pinHash });
});

// First-time PIN setup
router.post('/setup', (req, res) => {
  const existing = getSetting('pin_hash');
  if (existing) {
    return res.status(400).json({ error: 'PIN already set. Use change-pin instead.' });
  }

  const { pin } = req.body;
  if (!pin || pin.length < 4 || pin.length > 6) {
    return res.status(400).json({ error: 'PIN must be 4-6 digits' });
  }

  const hash = bcrypt.hashSync(pin, 10);
  setSetting('pin_hash', hash);

  const token = jwt.sign({ authenticated: true }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ success: true, token });
});

// Login with PIN
router.post('/login', (req, res) => {
  const { pin } = req.body;
  const pinHash = getSetting('pin_hash');

  if (!pinHash) {
    return res.status(400).json({ error: 'No PIN set. Please set up first.' });
  }

  if (!bcrypt.compareSync(pin, pinHash)) {
    return res.status(401).json({ error: 'Incorrect PIN' });
  }

  const token = jwt.sign({ authenticated: true }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ success: true, token });
});

// Change PIN (requires auth)
router.post('/change-pin', (req, res) => {
  const { currentPin, newPin } = req.body;
  const pinHash = getSetting('pin_hash');

  if (!pinHash) {
    return res.status(400).json({ error: 'No PIN set.' });
  }

  if (!bcrypt.compareSync(currentPin, pinHash)) {
    return res.status(401).json({ error: 'Current PIN is incorrect' });
  }

  if (!newPin || newPin.length < 4 || newPin.length > 6) {
    return res.status(400).json({ error: 'New PIN must be 4-6 digits' });
  }

  const hash = bcrypt.hashSync(newPin, 10);
  setSetting('pin_hash', hash);

  const token = jwt.sign({ authenticated: true }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ success: true, token });
});

module.exports = router;
