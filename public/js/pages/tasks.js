/* === Tasks Page === */
const TasksPage = {
  currentFilter: 'all',
  searchQuery: '',

  async render() {
    const container = document.getElementById('page-content');
    container.innerHTML = `
      <div class="filter-bar">
        <div class="filter-tabs">
          <button class="filter-tab ${this.currentFilter === 'all' ? 'active' : ''}" onclick="TasksPage.setFilter('all')">All</button>
          <button class="filter-tab ${this.currentFilter === 'todo' ? 'active' : ''}" onclick="TasksPage.setFilter('todo')">To Do</button>
          <button class="filter-tab ${this.currentFilter === 'in-progress' ? 'active' : ''}" onclick="TasksPage.setFilter('in-progress')">In Progress</button>
          <button class="filter-tab ${this.currentFilter === 'done' ? 'active' : ''}" onclick="TasksPage.setFilter('done')">Done</button>
        </div>
        <div class="search-wrapper">
          <input type="text" class="search-input" placeholder="Search tasks..." value="${this.searchQuery}" oninput="TasksPage.onSearch(this.value)" id="task-search">
        </div>
        <div style="flex:1"></div>
        <button class="btn btn-primary" onclick="TasksPage.openModal()">+ New Task</button>
      </div>
      <div class="task-list" id="task-list">
        <div class="loading-spinner"></div>
      </div>

      <!-- Task Modal -->
      <div class="modal-overlay" id="task-modal">
        <div class="modal">
          <div class="modal-header">
            <h3 id="task-modal-title">New Task</h3>
            <button class="modal-close" onclick="TasksPage.closeModal()">✕</button>
          </div>
          <div class="modal-body">
            <input type="hidden" id="task-edit-id">
            <div class="form-group">
              <label class="form-label">Title *</label>
              <input type="text" class="form-input" id="task-title" placeholder="What needs to be done?">
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea class="form-textarea" id="task-desc" placeholder="Add details..."></textarea>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">Priority</label>
                <select class="form-select" id="task-priority">
                  <option value="low">Low</option>
                  <option value="medium" selected>Medium</option>
                  <option value="high">High</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select class="form-select" id="task-status">
                  <option value="todo">To Do</option>
                  <option value="in-progress">In Progress</option>
                  <option value="done">Done</option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">Due Date</label>
                <input type="date" class="form-input" id="task-due">
              </div>
              <div class="form-group">
                <label class="form-label">Reminder Time</label>
                <input type="time" class="form-input" id="task-reminder">
              </div>
            </div>
            <div class="form-group">
              <label class="form-label">Category</label>
              <input type="text" class="form-input" id="task-category" placeholder="e.g. work, personal, study" value="general">
            </div>
            <div class="form-group">
              <label class="form-label">Related Goal <span style="font-weight:400; color:var(--text-tertiary);">(optional)</span></label>
              <select class="form-select" id="task-goal">
                <option value="">No related goal</option>
              </select>
              <div style="font-size: var(--text-xs); color: var(--text-tertiary); margin-top: var(--space-1);">Completed linked tasks automatically increase goal progress.</div>
            </div>
            <div class="form-group" id="task-assets-section" style="display:none;">
              <label class="form-label">Attachments</label>
              <div class="asset-list" id="task-asset-list"></div>
              <div class="upload-area" id="task-upload-area" style="margin-top: var(--space-2);">
                📎 Click or drag to upload files (max 10MB)
                <input type="file" id="task-file-input" style="display:none" multiple>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" onclick="TasksPage.closeModal()">Cancel</button>
            <button class="btn btn-primary" id="task-save-btn" onclick="TasksPage.saveTask()">Save Task</button>
          </div>
        </div>
      </div>
    `;

    this.loadGoalOptions();
    this.loadTasks();
  },

  async loadGoalOptions() {
    const select = document.getElementById('task-goal');
    if (!select) return;

    try {
      const goals = await API.getGoals();
      const selected = select.value;
      select.innerHTML = '<option value="">No related goal</option>' + goals.map(goal =>
        `<option value="${goal.id}">${this.escapeHtml(goal.title)}${goal.status === 'completed' ? ' (completed)' : ''}</option>`
      ).join('');
      if (selected) select.value = selected;
    } catch (error) {
      console.warn('[Tasks] Could not load goals:', error.message);
    }
  },

  async loadTasks() {
    const listEl = document.getElementById('task-list');
    try {
      const params = {};
      if (this.currentFilter !== 'all') params.status = this.currentFilter;
      if (this.searchQuery) params.search = this.searchQuery;

      const tasks = await API.getTasks(params);

      if (tasks.length === 0) {
        listEl.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon">📝</div>
            <h3>No tasks found</h3>
            <p>${this.currentFilter !== 'all' ? 'Try changing the filter' : 'Create your first task to get started'}</p>
          </div>
        `;
        return;
      }

      listEl.innerHTML = tasks.map(task => `
        <div class="task-item ${task.status === 'done' ? 'done' : ''}" data-id="${task.id}">
          <div class="task-checkbox ${task.status === 'done' ? 'checked' : ''}" onclick="TasksPage.toggleTask('${task.id}')">
            ${task.status === 'done' ? '✓' : ''}
          </div>
          <div class="task-content" onclick="TasksPage.openModal('${task.id}')">
            <div class="task-title">${this.escapeHtml(task.title)}</div>
            <div class="task-meta">
              <span class="badge badge-${task.status}">${task.status === 'in-progress' ? 'In Progress' : task.status === 'done' ? 'Done' : 'To Do'}</span>
              <span class="badge badge-${task.priority}">${task.priority}</span>
              <span>${task.category}</span>
              ${task.due_date ? `<span>📅 ${formatDateShort(task.due_date)}</span>` : ''}
              ${task.reminder_time ? `<span>⏰ ${task.reminder_time}</span>` : ''}
              ${task.goal ? `<span>🎯 ${this.escapeHtml(task.goal.title)}</span>` : ''}
              ${task.assets && task.assets.length > 0 ? `<span>📎 ${task.assets.length}</span>` : ''}
            </div>
          </div>
          <div class="task-actions">
            <button class="btn btn-ghost btn-sm" onclick="TasksPage.openModal('${task.id}')" title="Edit">✏️</button>
            <button class="btn btn-ghost btn-sm" onclick="TasksPage.deleteTask('${task.id}')" title="Delete">🗑️</button>
          </div>
        </div>
      `).join('');
    } catch (error) {
      listEl.innerHTML = `<div class="empty-state"><h3>Error loading tasks</h3><p>${error.message}</p></div>`;
    }
  },

  setFilter(filter) {
    this.currentFilter = filter;
    document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    this.loadTasks();
  },

  onSearch(value) {
    this.searchQuery = value;
    clearTimeout(this._searchTimer);
    this._searchTimer = setTimeout(() => this.loadTasks(), 300);
  },

  async openModal(taskId) {
    const modal = document.getElementById('task-modal');
    await this.loadGoalOptions();
    const titleEl = document.getElementById('task-modal-title');
    const assetsSection = document.getElementById('task-assets-section');

    // Reset form
    document.getElementById('task-edit-id').value = '';
    document.getElementById('task-title').value = '';
    document.getElementById('task-desc').value = '';
    document.getElementById('task-priority').value = 'medium';
    document.getElementById('task-status').value = 'todo';
    document.getElementById('task-due').value = getTodayStr();
    document.getElementById('task-reminder').value = '';
    document.getElementById('task-category').value = 'general';
    document.getElementById('task-goal').value = '';

    if (taskId) {
      titleEl.textContent = 'Edit Task';
      assetsSection.style.display = 'block';
      try {
        const task = await API.getTask(taskId);
        document.getElementById('task-edit-id').value = task.id;
        document.getElementById('task-title').value = task.title;
        document.getElementById('task-desc').value = task.description || '';
        document.getElementById('task-priority').value = task.priority;
        document.getElementById('task-status').value = task.status;
        document.getElementById('task-due').value = task.due_date || '';
        document.getElementById('task-reminder').value = task.reminder_time || '';
        document.getElementById('task-category').value = task.category || 'general';
        document.getElementById('task-goal').value = task.goal_id || '';
        this.renderAssets(task);
      } catch (error) {
        showToast('Failed to load task', 'error');
        return;
      }
    } else {
      titleEl.textContent = 'New Task';
      assetsSection.style.display = 'none';
    }

    modal.classList.add('active');

    // Upload area events
    const uploadArea = document.getElementById('task-upload-area');
    const fileInput = document.getElementById('task-file-input');
    uploadArea.onclick = () => fileInput.click();
    fileInput.onchange = (e) => this.handleUpload(e.target.files);
  },

  closeModal() {
    document.getElementById('task-modal').classList.remove('active');
  },

  renderAssets(task) {
    const container = document.getElementById('task-asset-list');
    if (!task.assets || task.assets.length === 0) {
      container.innerHTML = '<span style="font-size: var(--text-xs); color: var(--text-tertiary);">No attachments</span>';
      return;
    }
    container.innerHTML = task.assets.map(a => `
      <div class="asset-chip">
        <a href="/uploads/${a.file_path}" target="_blank">${this.escapeHtml(a.file_name)}</a>
        <span class="remove-asset" onclick="TasksPage.removeAsset('${task.id}', '${a.id}')">✕</span>
      </div>
    `).join('');
  },

  async handleUpload(files) {
    const taskId = document.getElementById('task-edit-id').value;
    if (!taskId) {
      showToast('Save the task first, then add attachments', 'info');
      return;
    }
    for (const file of files) {
      try {
        await API.uploadAsset(taskId, file);
        showToast(`Uploaded ${file.name}`, 'success');
      } catch (error) {
        showToast(`Failed to upload ${file.name}`, 'error');
      }
    }
    const task = await API.getTask(taskId);
    this.renderAssets(task);
  },

  async removeAsset(taskId, assetId) {
    if (!confirm('Remove this attachment?')) return;
    try {
      await API.deleteAsset(taskId, assetId);
      const task = await API.getTask(taskId);
      this.renderAssets(task);
      showToast('Attachment removed', 'success');
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async saveTask() {
    const id = document.getElementById('task-edit-id').value;
    const data = {
      title: document.getElementById('task-title').value,
      description: document.getElementById('task-desc').value,
      priority: document.getElementById('task-priority').value,
      status: document.getElementById('task-status').value,
      due_date: document.getElementById('task-due').value || null,
      reminder_time: document.getElementById('task-reminder').value || null,
      category: document.getElementById('task-category').value || 'general',
      goal_id: document.getElementById('task-goal').value || null,
    };

    if (!data.title.trim()) {
      showToast('Title is required', 'error');
      return;
    }

    try {
      if (id) {
        await API.updateTask(id, data);
        showToast('Task updated', 'success');
      } else {
        await API.createTask(data);
        showToast('Task created', 'success');
      }
      this.closeModal();
      this.loadTasks();
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async toggleTask(id) {
    try {
      await API.toggleTask(id);
      this.loadTasks();
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async deleteTask(id) {
    if (!confirm('Delete this task? This cannot be undone.')) return;
    try {
      await API.deleteTask(id);
      showToast('Task deleted', 'success');
      this.loadTasks();
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
