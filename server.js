require('dotenv').config();
const express = require('express');
const path = require('path');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files. `/assets` is also a Flutter route, so serve the SPA shell before
// Express normalizes the public/assets directory into a trailing-slash redirect.
app.get('/assets', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Auth middleware (skip for auth routes and static files)
function authMiddleware(req, res, next) {
  // Skip auth for these routes
  const publicPaths = ['/api/auth/', '/api/notifications/vapid-key'];
  if (publicPaths.some(p => req.originalUrl.startsWith(p))) {
    return next();
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const token = authHeader.split(' ')[1];
    jwt.verify(token, JWT_SECRET);
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// Apply auth middleware to all API routes
app.use('/api', authMiddleware);

// API Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/tasks', require('./routes/tasks'));
app.use('/api/library', require('./routes/library'));
app.use('/api/goals', require('./routes/goals'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/settings', require('./routes/settings'));

// SPA fallback — serve index.html for all non-API routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error handler
app.use((err, req, res, next) => {
  console.error('[Server] Error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// Vercel imports this file as a serverless function. Local development keeps
// the HTTP listener and background jobs; Vercel handles the request lifecycle.
if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`\n🚀 Productivity Dashboard running at http://localhost:${PORT}\n`);

    const { initVapidKeys } = require('./services/push');
    initVapidKeys();

    const { startScheduler } = require('./services/scheduler');
    startScheduler();
  });
}

module.exports = app;
