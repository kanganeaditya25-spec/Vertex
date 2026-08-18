/* === Reports Page === */
const ReportsPage = {
  currentTab: 'daily',

  async render() {
    const container = document.getElementById('page-content');
    container.innerHTML = `
      <div class="report-tabs">
        <button class="report-tab ${this.currentTab === 'daily' ? 'active' : ''}" onclick="ReportsPage.switchTab('daily')">📊 Daily</button>
        <button class="report-tab ${this.currentTab === 'monthly' ? 'active' : ''}" onclick="ReportsPage.switchTab('monthly')">📅 Monthly</button>
        <button class="report-tab ${this.currentTab === 'goals' ? 'active' : ''}" onclick="ReportsPage.switchTab('goals')">🎯 Goals</button>
      </div>
      <div id="report-content">
        <div class="loading-spinner"></div>
      </div>

      <!-- Goal Modal -->
      <div class="modal-overlay" id="goal-modal">
        <div class="modal">
          <div class="modal-header">
            <h3 id="goal-modal-title">New Goal</h3>
            <button class="modal-close" onclick="ReportsPage.closeGoalModal()">✕</button>
          </div>
          <div class="modal-body">
            <input type="hidden" id="goal-edit-id">
            <div class="form-group">
              <label class="form-label">Goal Title *</label>
              <input type="text" class="form-input" id="goal-title" placeholder="What do you want to achieve?">
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea class="form-textarea" id="goal-desc" placeholder="Describe your goal..."></textarea>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">Target Date</label>
                <input type="date" class="form-input" id="goal-target-date">
              </div>
              <div class="form-group">
                <label class="form-label">Progress (%)</label>
                <input type="number" class="form-input" id="goal-progress" min="0" max="100" value="0">
              </div>
            </div>
            <div class="form-group">
              <label class="form-label">Status</label>
              <select class="form-select" id="goal-status">
                <option value="active">Active</option>
                <option value="completed">Completed</option>
                <option value="paused">Paused</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Progress Note (optional)</label>
              <textarea class="form-textarea" id="goal-note" placeholder="Add a note about your progress..." style="min-height:60px;"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-danger" id="goal-delete-btn" onclick="ReportsPage.deleteGoal()" style="margin-right:auto; display:none;">Delete</button>
            <button class="btn btn-secondary" onclick="ReportsPage.closeGoalModal()">Cancel</button>
            <button class="btn btn-primary" onclick="ReportsPage.saveGoal()">Save Goal</button>
          </div>
        </div>
      </div>
    `;

    this.loadReport();
  },

  switchTab(tab) {
    this.currentTab = tab;
    document.querySelectorAll('.report-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    this.loadReport();
  },

  async loadReport() {
    const content = document.getElementById('report-content');
    content.innerHTML = '<div class="loading-spinner"></div>';

    try {
      if (this.currentTab === 'daily') await this.renderDailyReport(content);
      else if (this.currentTab === 'monthly') await this.renderMonthlyReport(content);
      else await this.renderGoalsReport(content);
    } catch (error) {
      content.innerHTML = `<div class="empty-state"><h3>Error loading report</h3><p>${error.message}</p></div>`;
    }
  },

  async renderDailyReport(container) {
    const report = await API.getDailyReport();

    const completed = report.tasks ? report.tasks.filter(t => t.status === 'done').length : 0;
    const total = report.tasks ? report.tasks.length : 0;

    container.innerHTML = `
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon blue">📋</div>
          <div class="stat-info">
            <h3>${report.stats.total}</h3>
            <p>Total Tasks</p>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon green">✅</div>
          <div class="stat-info">
            <h3>${report.stats.completed}</h3>
            <p>Completed</p>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon amber">🔄</div>
          <div class="stat-info">
            <h3>${report.stats.inProgress}</h3>
            <p>In Progress</p>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon ${report.stats.completionRate >= 70 ? 'green' : 'red'}">📈</div>
          <div class="stat-info">
            <h3>${report.stats.completionRate}%</h3>
            <p>Completion Rate</p>
          </div>
        </div>
      </div>

      ${report.aiInsights ? `
        <div class="ai-insight">
          <div class="ai-insight-header">✨ AI Analysis — ${formatDate(report.date)}</div>
          <p>${this.escapeHtml(report.aiInsights.summary || '')}</p>
          ${report.aiInsights.strengths && report.aiInsights.strengths.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">💪 Strengths</h4>
            <ul class="ai-list">
              ${report.aiInsights.strengths.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}
            </ul>
          ` : ''}
          ${report.aiInsights.improvements && report.aiInsights.improvements.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">🔧 Areas to Improve</h4>
            <ul class="ai-list">
              ${report.aiInsights.improvements.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}
            </ul>
          ` : ''}
          ${report.aiInsights.tip ? `
            <div style="margin-top: var(--space-4); padding: var(--space-3); background: white; border-radius: var(--radius-sm); font-size: var(--text-sm);">
              💡 <strong>Tip:</strong> ${this.escapeHtml(report.aiInsights.tip)}
            </div>
          ` : ''}
        </div>
      ` : `
        <div class="card" style="margin-bottom: var(--space-6);">
          <div class="card-title">✨ AI Insights</div>
          <p style="color: var(--text-tertiary); font-size: var(--text-sm); margin-top: var(--space-2);">
            Add your Gemini API key in Settings to get AI-powered analysis and suggestions.
          </p>
        </div>
      `}

      ${total > 0 ? `
        <div class="card">
          <div class="card-title">Today's Task Breakdown</div>
          <div class="task-list" style="margin-top: var(--space-4);">
            ${report.tasks.map(t => `
              <div class="task-item ${t.status === 'done' ? 'done' : ''}">
                <div class="task-checkbox ${t.status === 'done' ? 'checked' : ''}">${t.status === 'done' ? '✓' : ''}</div>
                <div class="task-content">
                  <div class="task-title">${this.escapeHtml(t.title)}</div>
                  <div class="task-meta">
                    <span class="badge badge-${t.status}">${t.status}</span>
                    <span class="badge badge-${t.priority}">${t.priority}</span>
                  </div>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      ` : ''}
    `;
  },

  async renderMonthlyReport(container) {
    const now = new Date();
    const report = await API.getMonthlyReport(now.getMonth() + 1, now.getFullYear());

    const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];

    container.innerHTML = `
      <h3 style="font-size: var(--text-lg); font-weight: 600; margin-bottom: var(--space-6);">
        ${monthNames[report.stats.month - 1]} ${report.stats.year}
      </h3>

      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-icon blue">📋</div>
          <div class="stat-info">
            <h3>${report.stats.total}</h3>
            <p>Total Tasks</p>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon green">✅</div>
          <div class="stat-info">
            <h3>${report.stats.completed}</h3>
            <p>Completed</p>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon ${report.stats.completionRate >= 70 ? 'green' : 'amber'}">📈</div>
          <div class="stat-info">
            <h3>${report.stats.completionRate}%</h3>
            <p>Completion Rate</p>
          </div>
        </div>
      </div>

      ${report.stats.categories && Object.keys(report.stats.categories).length > 0 ? `
        <div class="card" style="margin-bottom: var(--space-6);">
          <div class="card-title">Category Breakdown</div>
          <div style="margin-top: var(--space-4);">
            ${Object.entries(report.stats.categories).map(([cat, data]) => `
              <div style="display: flex; align-items: center; gap: var(--space-4); padding: var(--space-3) 0; border-bottom: 1px solid var(--border-light);">
                <span style="font-weight: 500; width: 120px;">${this.escapeHtml(cat)}</span>
                <div class="progress-bar" style="flex: 1;">
                  <div class="progress-bar-fill ${data.total > 0 && (data.done / data.total) >= 0.7 ? 'green' : 'amber'}" style="width: ${data.total > 0 ? (data.done / data.total * 100) : 0}%"></div>
                </div>
                <span style="font-size: var(--text-sm); color: var(--text-tertiary); width: 60px; text-align: right;">${data.done}/${data.total}</span>
              </div>
            `).join('')}
          </div>
        </div>
      ` : ''}

      ${report.aiInsights ? `
        <div class="ai-insight">
          <div class="ai-insight-header">✨ Monthly AI Analysis</div>
          <p>${this.escapeHtml(report.aiInsights.summary || '')}</p>
          ${report.aiInsights.strengths && report.aiInsights.strengths.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">💪 Strengths</h4>
            <ul class="ai-list">${report.aiInsights.strengths.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}</ul>
          ` : ''}
          ${report.aiInsights.improvements && report.aiInsights.improvements.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">🔧 Improvements</h4>
            <ul class="ai-list">${report.aiInsights.improvements.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}</ul>
          ` : ''}
          ${report.aiInsights.nextMonthGoals && report.aiInsights.nextMonthGoals.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">🎯 Suggested Goals for Next Month</h4>
            <ul class="ai-list">${report.aiInsights.nextMonthGoals.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}</ul>
          ` : ''}
        </div>
      ` : `
        <div class="card">
          <div class="card-title">✨ AI Insights</div>
          <p style="color: var(--text-tertiary); font-size: var(--text-sm); margin-top: var(--space-2);">Add your Gemini API key in Settings to get AI-powered monthly analysis.</p>
        </div>
      `}
    `;
  },

  async renderGoalsReport(container) {
    const report = await API.getGoalsReport();
    const goals = report.goals || [];

    container.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: var(--space-6);">
        <div class="stats-grid" style="flex:1; margin-bottom: 0;">
          <div class="stat-card">
            <div class="stat-icon blue">🎯</div>
            <div class="stat-info">
              <h3>${report.stats.total}</h3>
              <p>Total Goals</p>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon green">✅</div>
            <div class="stat-info">
              <h3>${report.stats.completed}</h3>
              <p>Completed</p>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon amber">📊</div>
            <div class="stat-info">
              <h3>${report.stats.averageProgress}%</h3>
              <p>Avg Progress</p>
            </div>
          </div>
        </div>
      </div>

      <div style="margin-bottom: var(--space-6);">
        <button class="btn btn-primary" onclick="ReportsPage.openGoalModal()">+ New Goal</button>
      </div>

      ${report.aiInsights ? `
        <div class="ai-insight" style="margin-bottom: var(--space-6);">
          <div class="ai-insight-header">✨ Goal Analysis</div>
          <p>${this.escapeHtml(report.aiInsights.summary || '')}</p>
          ${report.aiInsights.performingWell && report.aiInsights.performingWell.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">💪 Performing Well</h4>
            <ul class="ai-list">${report.aiInsights.performingWell.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}</ul>
          ` : ''}
          ${report.aiInsights.needsAttention && report.aiInsights.needsAttention.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">⚠️ Needs Attention</h4>
            <ul class="ai-list">${report.aiInsights.needsAttention.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}</ul>
          ` : ''}
          ${report.aiInsights.suggestions && report.aiInsights.suggestions.length ? `
            <h4 style="margin-top: var(--space-4); margin-bottom: var(--space-2); font-size: var(--text-sm);">💡 Suggestions</h4>
            <ul class="ai-list">${report.aiInsights.suggestions.map(s => `<li>${this.escapeHtml(s)}</li>`).join('')}</ul>
          ` : ''}
        </div>
      ` : ''}

      <div id="goals-list">
        ${goals.length === 0 ? `
          <div class="empty-state">
            <div class="empty-icon">🎯</div>
            <h3>No goals yet</h3>
            <p>Set your first permanent goal to start tracking progress</p>
          </div>
        ` : goals.map(goal => {
          let notes = [];
          try { notes = JSON.parse(goal.progress_notes || '[]'); } catch(e) {}

          return `
            <div class="goal-card" onclick="ReportsPage.openGoalModal('${goal.id}')">
              <div class="goal-card-header">
                <div>
                  <div class="goal-card-title">${this.escapeHtml(goal.title)}</div>
                  ${goal.description ? `<p style="font-size: var(--text-sm); color: var(--text-secondary); margin-top: var(--space-1);">${this.escapeHtml(goal.description)}</p>` : ''}
                </div>
                <span class="badge badge-${goal.status === 'completed' ? 'done' : goal.status === 'paused' ? 'todo' : 'in-progress'}">${goal.status}</span>
              </div>
              <div class="goal-progress-label">
                <span>Progress</span>
                <span>${goal.progress}%</span>
              </div>
              <div class="progress-bar">
                <div class="progress-bar-fill ${goal.progress >= 70 ? 'green' : goal.progress >= 30 ? 'amber' : 'red'}" style="width: ${goal.progress}%"></div>
              </div>
              ${goal.target_date ? `<div style="font-size: var(--text-xs); color: var(--text-tertiary); margin-top: var(--space-2);">Target: ${formatDate(goal.target_date)}</div>` : ''}
              ${notes.length > 0 ? `
                <div style="margin-top: var(--space-3); padding-top: var(--space-3); border-top: 1px solid var(--border-light);">
                  <div style="font-size: var(--text-xs); font-weight: 600; color: var(--text-secondary); margin-bottom: var(--space-2);">Recent Notes</div>
                  ${notes.slice(-2).reverse().map(n => `
                    <div style="font-size: var(--text-xs); color: var(--text-tertiary); padding: var(--space-1) 0;">
                      ${formatDateShort(n.date)} — ${this.escapeHtml(n.note)} (${n.progress}%)
                    </div>
                  `).join('')}
                </div>
              ` : ''}
            </div>
          `;
        }).join('')}
      </div>
    `;
  },

  openGoalModal(goalId) {
    const modal = document.getElementById('goal-modal');
    const deleteBtn = document.getElementById('goal-delete-btn');

    document.getElementById('goal-edit-id').value = '';
    document.getElementById('goal-title').value = '';
    document.getElementById('goal-desc').value = '';
    document.getElementById('goal-target-date').value = '';
    document.getElementById('goal-progress').value = '0';
    document.getElementById('goal-status').value = 'active';
    document.getElementById('goal-note').value = '';
    deleteBtn.style.display = 'none';

    if (goalId) {
      document.getElementById('goal-modal-title').textContent = 'Edit Goal';
      deleteBtn.style.display = 'block';
      API.request(`/goals/${goalId}`).then(goal => {
        document.getElementById('goal-edit-id').value = goal.id;
        document.getElementById('goal-title').value = goal.title;
        document.getElementById('goal-desc').value = goal.description || '';
        document.getElementById('goal-target-date').value = goal.target_date || '';
        document.getElementById('goal-progress').value = goal.progress;
        document.getElementById('goal-status').value = goal.status;
      });
    } else {
      document.getElementById('goal-modal-title').textContent = 'New Goal';
    }

    modal.classList.add('active');
  },

  closeGoalModal() {
    document.getElementById('goal-modal').classList.remove('active');
  },

  async saveGoal() {
    const id = document.getElementById('goal-edit-id').value;
    const data = {
      title: document.getElementById('goal-title').value,
      description: document.getElementById('goal-desc').value,
      target_date: document.getElementById('goal-target-date').value || null,
      progress: parseInt(document.getElementById('goal-progress').value) || 0,
      status: document.getElementById('goal-status').value,
      progress_note: document.getElementById('goal-note').value || null,
    };

    if (!data.title.trim()) {
      showToast('Goal title is required', 'error');
      return;
    }

    try {
      if (id) {
        await API.updateGoal(id, data);
        showToast('Goal updated', 'success');
      } else {
        await API.createGoal(data);
        showToast('Goal created', 'success');
      }
      this.closeGoalModal();
      this.loadReport();
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async deleteGoal() {
    const id = document.getElementById('goal-edit-id').value;
    if (!id || !confirm('Delete this goal? This cannot be undone.')) return;
    try {
      await API.deleteGoal(id);
      showToast('Goal deleted', 'success');
      this.closeGoalModal();
      this.loadReport();
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
