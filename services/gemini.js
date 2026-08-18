const { GoogleGenAI } = require('@google/genai');
const { getSetting } = require('../db/database');

function getClient() {
  const apiKey = getSetting('gemini_api_key') || process.env.GEMINI_API_KEY;
  if (!apiKey) return null;
  return new GoogleGenAI({ apiKey });
}

async function generateWithAI(prompt) {
  const client = getClient();
  if (!client) {
    return null; // No API key configured
  }

  try {
    const response = await client.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
    });
    return response.text;
  } catch (error) {
    console.error('[Gemini] API error:', error.message);
    return null;
  }
}

async function generateDailyReport(tasks) {
  const completed = tasks.filter(t => t.status === 'done');
  const pending = tasks.filter(t => t.status !== 'done');
  const inProgress = tasks.filter(t => t.status === 'in-progress');

  const stats = {
    total: tasks.length,
    completed: completed.length,
    inProgress: inProgress.length,
    pending: pending.length,
    completionRate: tasks.length > 0 ? Math.round((completed.length / tasks.length) * 100) : 0
  };

  const prompt = `You are a productivity coach. Analyze this daily task report and provide brief, actionable insights.

Today's Stats:
- Total tasks: ${stats.total}
- Completed: ${stats.completed}
- In Progress: ${stats.inProgress}  
- Pending: ${stats.pending}
- Completion Rate: ${stats.completionRate}%

Completed tasks: ${completed.map(t => `"${t.title}" (${t.priority} priority, category: ${t.category})`).join(', ') || 'None'}

Pending tasks: ${pending.map(t => `"${t.title}" (${t.priority} priority, category: ${t.category}, due: ${t.due_date || 'no due date'})`).join(', ') || 'None'}

Provide your response in this JSON format (no markdown, just raw JSON):
{
  "summary": "2-3 sentence summary of the day",
  "strengths": ["what went well point 1", "point 2"],
  "improvements": ["suggestion 1", "suggestion 2"],
  "tip": "one motivational productivity tip for tomorrow"
}`;

  const aiResponse = await generateWithAI(prompt);
  let aiInsights = null;

  if (aiResponse) {
    try {
      const cleaned = aiResponse.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      aiInsights = JSON.parse(cleaned);
    } catch (e) {
      aiInsights = { summary: aiResponse, strengths: [], improvements: [], tip: '' };
    }
  }

  return { stats, aiInsights };
}

async function generateMonthlyReport(tasks, month, year) {
  const completed = tasks.filter(t => t.status === 'done');
  const total = tasks.length;
  
  // Group by category
  const categories = {};
  tasks.forEach(t => {
    if (!categories[t.category]) categories[t.category] = { total: 0, done: 0 };
    categories[t.category].total++;
    if (t.status === 'done') categories[t.category].done++;
  });

  // Group by day for heatmap
  const dailyData = {};
  tasks.forEach(t => {
    const day = t.created_at ? t.created_at.split('T')[0].split(' ')[0] : 'unknown';
    if (!dailyData[day]) dailyData[day] = { total: 0, done: 0 };
    dailyData[day].total++;
    if (t.status === 'done') dailyData[day].done++;
  });

  // Priority breakdown
  const priorities = { high: 0, medium: 0, low: 0 };
  completed.forEach(t => { if (priorities[t.priority] !== undefined) priorities[t.priority]++; });

  const stats = {
    total,
    completed: completed.length,
    completionRate: total > 0 ? Math.round((completed.length / total) * 100) : 0,
    categories,
    dailyData,
    priorities,
    month,
    year
  };

  const prompt = `You are a productivity coach. Analyze this monthly task report and give insights.

Month: ${month}/${year}
Total Tasks: ${total}
Completed: ${completed.length} (${stats.completionRate}%)

Category breakdown: ${JSON.stringify(categories)}
Priority breakdown of completed tasks: ${JSON.stringify(priorities)}

Provide your response in this JSON format (no markdown, just raw JSON):
{
  "summary": "3-4 sentence monthly summary",
  "topCategory": "the category with most activity",
  "strengths": ["strength 1", "strength 2", "strength 3"],
  "improvements": ["area to improve 1", "area to improve 2"],
  "nextMonthGoals": ["suggested goal 1", "suggested goal 2", "suggested goal 3"]
}`;

  const aiResponse = await generateWithAI(prompt);
  let aiInsights = null;

  if (aiResponse) {
    try {
      const cleaned = aiResponse.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      aiInsights = JSON.parse(cleaned);
    } catch (e) {
      aiInsights = { summary: aiResponse, strengths: [], improvements: [], nextMonthGoals: [] };
    }
  }

  return { stats, aiInsights };
}

async function generateGoalAnalysis(goals, recentTasks) {
  const activeGoals = goals.filter(g => g.status === 'active');
  const completedGoals = goals.filter(g => g.status === 'completed');

  const stats = {
    total: goals.length,
    active: activeGoals.length,
    completed: completedGoals.length,
    averageProgress: activeGoals.length > 0
      ? Math.round(activeGoals.reduce((sum, g) => sum + g.progress, 0) / activeGoals.length)
      : 0
  };

  const prompt = `You are a productivity and goal-setting coach. Analyze these goals and recent activity to provide deep insights.

Active Goals:
${activeGoals.map(g => `- "${g.title}" (Progress: ${g.progress}%, Target: ${g.target_date || 'no date'}, Description: ${g.description})`).join('\n') || 'None'}

Completed Goals:
${completedGoals.map(g => `- "${g.title}"`).join('\n') || 'None'}

Recent Tasks (last 30 days): ${recentTasks.length} tasks, ${recentTasks.filter(t => t.status === 'done').length} completed

Provide your response in this JSON format (no markdown, just raw JSON):
{
  "summary": "3-4 sentence analysis of goal progress",
  "performingWell": ["area doing well 1", "area doing well 2"],
  "needsAttention": ["area lacking 1", "area lacking 2"],
  "suggestions": ["actionable suggestion 1", "actionable suggestion 2", "actionable suggestion 3"],
  "goalSpecificFeedback": [{"goal": "goal title", "feedback": "specific feedback"}]
}`;

  const aiResponse = await generateWithAI(prompt);
  let aiInsights = null;

  if (aiResponse) {
    try {
      const cleaned = aiResponse.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      aiInsights = JSON.parse(cleaned);
    } catch (e) {
      aiInsights = { summary: aiResponse, performingWell: [], needsAttention: [], suggestions: [] };
    }
  }

  return { stats, aiInsights };
}

module.exports = { generateDailyReport, generateMonthlyReport, generateGoalAnalysis };
