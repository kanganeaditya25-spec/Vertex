const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getSetting, setSetting } = require('../db/database');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';
const ACCOUNT_EMAIL_KEY = 'account_email';
const ACCOUNT_NAME_KEY = 'account_name';
const ACCOUNT_PASSWORD_HASH_KEY = 'account_password_hash';

function issueToken(email) {
  return jwt.sign({ authenticated: true, email: email || undefined }, JWT_SECRET, { expiresIn: '7d' });
}

function validEmail(email) {
  return typeof email === 'string' && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim());
}

function validPassword(password) {
  return typeof password === 'string' && password.length >= 8;
}

// Check if PIN is set up
router.get('/status', (req, res) => {
  const pinHash = getSetting('pin_hash');
  res.json({
    isSetup: !!pinHash,
    accountExists: !!getSetting(ACCOUNT_EMAIL_KEY),
  });
});

// Create the account used by the offline-first Flutter client when the API is reachable.
router.post('/signup', (req, res) => {
  const { name, email, password } = req.body || {};
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
  const normalizedName = typeof name === 'string' ? name.trim() : '';
  if (normalizedName.length < 2 || !validEmail(normalizedEmail) || !validPassword(password)) {
    return res.status(400).json({ error: 'Name, valid email, and password of at least 8 characters are required' });
  }
  const existingEmail = getSetting(ACCOUNT_EMAIL_KEY);
  if (existingEmail && existingEmail !== normalizedEmail) {
    return res.status(409).json({ error: 'A local account already exists on this workspace' });
  }
  if (existingEmail === normalizedEmail) {
    return res.status(409).json({ error: 'An account with this email already exists. Sign in instead.' });
  }
  setSetting(ACCOUNT_EMAIL_KEY, normalizedEmail);
  setSetting(ACCOUNT_NAME_KEY, normalizedName);
  setSetting(ACCOUNT_PASSWORD_HASH_KEY, bcrypt.hashSync(password, 10));
  return res.json({ success: true, token: issueToken(normalizedEmail), name: normalizedName, email: normalizedEmail });
});

// Email/password sign-in for the Flutter client; PIN sign-in remains available below.
router.post('/email-login', (req, res) => {
  const { email, password } = req.body || {};
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
  const accountEmail = getSetting(ACCOUNT_EMAIL_KEY);
  const passwordHash = getSetting(ACCOUNT_PASSWORD_HASH_KEY);
  if (!accountEmail || !passwordHash) {
    return res.status(400).json({ error: 'No email account exists. Sign up first.' });
  }
  if (normalizedEmail !== accountEmail || !bcrypt.compareSync(password || '', passwordHash)) {
    return res.status(401).json({ error: 'Email or password is incorrect' });
  }
  return res.json({ success: true, token: issueToken(normalizedEmail), name: getSetting(ACCOUNT_NAME_KEY) || 'there', email: normalizedEmail });
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

  const token = issueToken('');
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

  const token = issueToken('');
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

  const token = issueToken('');
  res.json({ success: true, token });
});

module.exports = router;
