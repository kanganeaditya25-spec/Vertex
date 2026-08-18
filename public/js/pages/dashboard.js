/* === Dashboard Page === */
const DashboardPage = {
  async render() {
    const container = document.getElementById('page-content');
    container.innerHTML = '<div class="loading-spinner"></div>';

    try {
      const today = getTodayStr();
      const tasks = await API.getTasks();
      const goals = await API.getGoals();

      const todayTasks = tasks.filter(t => {
        const created = t.created_at ? t.created_at.split('T')[0].split(' ')[0] : '';
        return t.due_date === today || created === today;
      });

      const completedToday = todayTasks.filter(t => t.status === 'done').length;
      const pendingAll = tasks.filter(t => t.status !== 'done').length;
      const overdue = tasks.filter(t => t.due_date && t.due_date < today && t.status !== 'done').length;
      const activeGoals = goals.filter(g => g.status === 'active').length;

      container.innerHTML = `
        <div class="stats-grid">
          <div class="stat-card">
            <div class="stat-icon blue">📋</div>
            <div class="stat-info">
              <h3>${todayTasks.length}</h3>
              <p>Today's Tasks</p>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon green">✅</div>
            <div class="stat-info">
              <h3>${completedToday}</h3>
              <p>Completed Today</p>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon amber">⏳</div>
            <div class="stat-info">
              <h3>${pendingAll}</h3>
              <p>Total Pending</p>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon red">${overdue > 0 ? '⚠️' : '🎯'}</div>
            <div class="stat-info">
              <h3>${overdue > 0 ? overdue : activeGoals}</h3>
              <p>${overdue > 0 ? 'Overdue' : 'Active Goals'}</p>
            </div>
          </div>
        </div>

        <div style="display:grid; grid-template-columns: 1fr 1fr; gap: var(--space-6);">
          <div class="card">
            <div class="card-header">
              <div>
                <div class="card-title">Today's Tasks</div>
                <div class="card-subtitle">${today}</div>
              </div>
              <button class="btn btn-primary btn-sm" onclick="window.location.hash='#tasks'">View All</button>
            </div>
            <div class="task-list" id="dashboard-tasks">
              ${todayTasks.length === 0 ? `
                <div class="empty-state" style="padding: var(--space-6);">
                  <div class="empty-icon">📝</div>
                  <p>No tasks for today. Add some!</p>
                </div>
              ` : todayTasks.slice(0, 6).map(task => `
                <div class="task-item ${task.status === 'done' ? 'done' : ''}" data-id="${task.id}">
                  <div class="task-checkbox ${task.status === 'done' ? 'checked' : ''}" onclick="DashboardPage.toggleTask('${task.id}')">
                    ${task.status === 'done' ? '✓' : ''}
                  </div>
                  <div class="task-content">
                    <div class="task-title">${this.escapeHtml(task.title)}</div>
                    <div class="task-meta">
                      <span class="badge badge-${task.priority}">${task.priority}</span>
                      <span>${task.category}</span>
                    </div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <div class="card">
            <div class="card-header">
              <div>
                <div class="card-title">Active Goals</div>
                <div class="card-subtitle">${activeGoals} goals in progress</div>
              </div>
              <button class="btn btn-primary btn-sm" onclick="window.location.hash='#reports'">Reports</button>
            </div>
            ${goals.filter(g => g.status === 'active').length === 0 ? `
              <div class="empty-state" style="padding: var(--space-6);">
                <div class="empty-icon">🎯</div>
                <p>No active goals. Set your first goal!</p>
              </div>
            ` : goals.filter(g => g.status === 'active').slice(0, 4).map(goal => `
              <div class="goal-card" style="margin-bottom: var(--space-3);">
                <div class="goal-card-header">
                  <div class="goal-card-title">${this.escapeHtml(goal.title)}</div>
                  <span class="badge badge-in-progress">${goal.progress}%</span>
                </div>
                <div class="progress-bar">
                  <div class="progress-bar-fill ${goal.progress >= 70 ? 'green' : goal.progress >= 30 ? 'amber' : 'red'}" style="width: ${goal.progress}%"></div>
                </div>
              </div>
            `).join('')}
          </div>
        </div>

        ${overdue > 0 ? `
          <div class="card" style="margin-top: var(--space-6); border-color: var(--danger);">
            <div class="card-header">
              <div class="card-title" style="color: var(--danger);">⚠️ Overdue Tasks</div>
            </div>
            <div class="task-list">
              ${tasks.filter(t => t.due_date && t.due_date < today && t.status !== 'done').slice(0, 5).map(task => `
                <div class="task-item" data-id="${task.id}">
                  <div class="task-checkbox" onclick="DashboardPage.toggleTask('${task.id}')"></div>
                  <div class="task-content">
                    <div class="task-title">${this.escapeHtml(task.title)}</div>
                    <div class="task-meta">
                      <span class="badge badge-high">overdue</span>
                      <span>Due ${formatDate(task.due_date)}</span>
                    </div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}
      `;
    } catch (error) {
      container.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><h3>Error loading dashboard</h3><p>${error.message}</p></div>`;
    }
  },

  async toggleTask(id) {
    try {
      await API.toggleTask(id);
      this.render();
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
};
