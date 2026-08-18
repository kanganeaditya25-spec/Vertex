const baseUrl = 'http://localhost:3000';

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: { 'content-type': 'application/json', ...(options.headers || {}) }
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`${options.method || 'GET'} ${path} failed (${response.status}): ${JSON.stringify(body)}`);
  return body;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

(async () => {
  let goalId;
  let taskId;

  try {
    const login = await request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ pin: '123456' })
    });
    const auth = { authorization: `Bearer ${login.token}` };

    const goal = await request('/api/goals', {
      method: 'POST',
      headers: auth,
      body: JSON.stringify({ title: `Linked goal smoke test ${Date.now()}` })
    });
    goalId = goal.id;
    assert(goal.linked_task_count === 0 && goal.progress === 0, `Unexpected new goal: ${JSON.stringify(goal)}`);

    const task = await request('/api/tasks', {
      method: 'POST',
      headers: auth,
      body: JSON.stringify({ title: `Linked task smoke test ${Date.now()}`, goal_id: goalId })
    });
    taskId = task.id;
    assert(task.goal_id === goalId, `Task was not linked: ${JSON.stringify(task)}`);

    let currentGoal = await request(`/api/goals/${goalId}`, { headers: auth });
    assert(currentGoal.progress === 0 && currentGoal.pending_task_count === 1, `Initial goal stats incorrect: ${JSON.stringify(currentGoal)}`);

    const completedTask = await request(`/api/tasks/${taskId}/toggle`, { method: 'PATCH', headers: auth });
    assert(completedTask.status === 'done', `Task did not complete: ${JSON.stringify(completedTask)}`);

    currentGoal = await request(`/api/goals/${goalId}`, { headers: auth });
    assert(currentGoal.progress === 100 && currentGoal.status === 'completed' && currentGoal.completed_task_count === 1, `Goal did not auto-complete: ${JSON.stringify(currentGoal)}`);

    await request(`/api/tasks/${taskId}/toggle`, { method: 'PATCH', headers: auth });
    currentGoal = await request(`/api/goals/${goalId}`, { headers: auth });
    assert(currentGoal.progress === 0 && currentGoal.status === 'active' && currentGoal.pending_task_count === 1, `Goal did not reverse after reopening task: ${JSON.stringify(currentGoal)}`);

    console.log(JSON.stringify({ goalId, taskId, initialProgress: 0, completedProgress: 100, reopenedProgress: currentGoal.progress }, null, 2));
  } finally {
    const login = await request('/api/auth/login', { method: 'POST', body: JSON.stringify({ pin: '123456' }) }).catch(() => null);
    if (login?.token) {
      const auth = { authorization: `Bearer ${login.token}` };
      if (taskId) await request(`/api/tasks/${taskId}`, { method: 'DELETE', headers: auth }).catch(() => {});
      if (goalId) await request(`/api/goals/${goalId}`, { method: 'DELETE', headers: auth }).catch(() => {});
    }
  }
})().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
