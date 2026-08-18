const express = require('express');
const { db } = require('../db/database');
const { generateDailyReport, generateMonthlyReport, generateGoalAnalysis } = require('../services/gemini');

const router = express.Router();

// Daily report
router.get('/daily', async (req, res) => {
  try {
    const { date } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    // Get tasks for the day (created on or due on that date)
    const tasks = db.prepare(`
      SELECT * FROM tasks 
      WHERE due_date = ? OR date(created_at) = ?
      ORDER BY created_at DESC
    `).all(targetDate, targetDate);

    const report = await generateDailyReport(tasks);
    report.date = targetDate;
    report.tasks = tasks;

    res.json(report);
  } catch (error) {
    console.error('[Reports] Daily report error:', error);
    res.status(500).json({ error: 'Failed to generate daily report' });
  }
});

// Monthly report
router.get('/monthly', async (req, res) => {
  try {
    const now = new Date();
    const month = parseInt(req.query.month) || (now.getMonth() + 1);
    const year = parseInt(req.query.year) || now.getFullYear();

    const monthStr = String(month).padStart(2, '0');
    const startDate = `${year}-${monthStr}-01`;
    const endDate = month === 12
      ? `${year + 1}-01-01`
      : `${year}-${String(month + 1).padStart(2, '0')}-01`;

    const tasks = db.prepare(`
      SELECT * FROM tasks 
      WHERE (due_date >= ? AND due_date < ?) OR (date(created_at) >= ? AND date(created_at) < ?)
      ORDER BY created_at DESC
    `).all(startDate, endDate, startDate, endDate);

    const report = await generateMonthlyReport(tasks, month, year);
    report.tasks = tasks;

    res.json(report);
  } catch (error) {
    console.error('[Reports] Monthly report error:', error);
    res.status(500).json({ error: 'Failed to generate monthly report' });
  }
});

// Goals analysis report
router.get('/goals', async (req, res) => {
  try {
    const goals = db.prepare('SELECT * FROM goals ORDER BY created_at DESC').all();

    // Get tasks from last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const recentTasks = db.prepare(
      "SELECT * FROM tasks WHERE created_at >= ?"
    ).all(thirtyDaysAgo.toISOString());

    const report = await generateGoalAnalysis(goals, recentTasks);
    report.goals = goals;

    res.json(report);
  } catch (error) {
    console.error('[Reports] Goals report error:', error);
    res.status(500).json({ error: 'Failed to generate goals report' });
  }
});

module.exports = router;
