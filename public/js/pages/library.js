/* === Library Page === */
const LibraryPage = {
  currentCategory: 'all',
  searchQuery: '',

  async render() {
    const container = document.getElementById('page-content');
    container.innerHTML = `
      <div class="filter-bar">
        <div class="filter-tabs">
          <button class="filter-tab ${this.currentCategory === 'all' ? 'active' : ''}" onclick="LibraryPage.setCategory('all')">All</button>
          <button class="filter-tab ${this.currentCategory === 'project' ? 'active' : ''}" onclick="LibraryPage.setCategory('project')">Projects</button>
          <button class="filter-tab ${this.currentCategory === 'idea' ? 'active' : ''}" onclick="LibraryPage.setCategory('idea')">Ideas</button>
          <button class="filter-tab ${this.currentCategory === 'resource' ? 'active' : ''}" onclick="LibraryPage.setCategory('resource')">Resources</button>
        </div>
        <div class="search-wrapper">
          <input type="text" class="search-input" placeholder="Search library..." value="${this.searchQuery}" oninput="LibraryPage.onSearch(this.value)">
        </div>
        <div style="flex:1"></div>
        <button class="btn btn-primary" onclick="LibraryPage.openModal()">+ Add Item</button>
      </div>
      <div class="library-grid" id="library-grid">
        <div class="loading-spinner"></div>
      </div>

      <!-- Library Modal -->
      <div class="modal-overlay" id="library-modal">
        <div class="modal">
          <div class="modal-header">
            <h3 id="library-modal-title">Add to Library</h3>
            <button class="modal-close" onclick="LibraryPage.closeModal()">✕</button>
          </div>
          <div class="modal-body">
            <input type="hidden" id="lib-edit-id">
            <div class="form-group">
              <label class="form-label">Title *</label>
              <input type="text" class="form-input" id="lib-title" placeholder="Project name, idea title, or resource name">
            </div>
            <div class="form-group">
              <label class="form-label">URL / Link</label>
              <input type="url" class="form-input" id="lib-url" placeholder="https://...">
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea class="form-textarea" id="lib-desc" placeholder="Add notes or description..."></textarea>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">Category</label>
                <select class="form-select" id="lib-category">
                  <option value="project">Project</option>
                  <option value="idea">Idea</option>
                  <option value="resource">Study Resource</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tags (comma separated)</label>
                <input type="text" class="form-input" id="lib-tags" placeholder="react, tutorial, frontend">
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" onclick="LibraryPage.closeModal()">Cancel</button>
            <button class="btn btn-primary" onclick="LibraryPage.saveItem()">Save</button>
          </div>
        </div>
      </div>
    `;

    this.loadItems();
  },

  async loadItems() {
    const grid = document.getElementById('library-grid');
    try {
      const params = {};
      if (this.currentCategory !== 'all') params.category = this.currentCategory;
      if (this.searchQuery) params.search = this.searchQuery;

      const items = await API.getLibrary(params);

      if (items.length === 0) {
        grid.innerHTML = `
          <div class="empty-state" style="grid-column: 1/-1;">
            <div class="empty-icon">📚</div>
            <h3>Library is empty</h3>
            <p>Save your project links, ideas, and study resources here</p>
          </div>
        `;
        return;
      }

      grid.innerHTML = items.map(item => {
        let tags = [];
        try { tags = JSON.parse(item.tags || '[]'); } catch(e) {}

        return `
          <div class="library-card" onclick="LibraryPage.openModal('${item.id}')">
            <div class="library-card-header">
              <div class="library-card-title">${this.escapeHtml(item.title)}</div>
              <span class="badge badge-${item.category}">${item.category}</span>
            </div>
            ${item.description ? `<div class="library-card-desc">${this.escapeHtml(item.description)}</div>` : ''}
            ${item.url ? `<a class="library-card-url" href="${this.escapeHtml(item.url)}" target="_blank" onclick="event.stopPropagation()">${this.escapeHtml(item.url)}</a>` : ''}
            ${tags.length > 0 ? `
              <div class="library-card-tags">
                ${tags.map(t => `<span class="tag">${this.escapeHtml(t)}</span>`).join('')}
              </div>
            ` : ''}
            <div style="display:flex; justify-content:space-between; align-items:center; margin-top: var(--space-3); padding-top: var(--space-3); border-top: 1px solid var(--border-light);">
              <span style="font-size: var(--text-xs); color: var(--text-tertiary);">${formatDate(item.created_at)}</span>
              <button class="btn btn-ghost btn-sm" onclick="event.stopPropagation(); LibraryPage.deleteItem('${item.id}')" title="Delete">🗑️</button>
            </div>
          </div>
        `;
      }).join('');
    } catch (error) {
      grid.innerHTML = `<div class="empty-state" style="grid-column: 1/-1;"><h3>Error loading library</h3><p>${error.message}</p></div>`;
    }
  },

  setCategory(cat) {
    this.currentCategory = cat;
    document.querySelectorAll('.filter-tab').forEach(t => t.classList.remove('active'));
    event.target.classList.add('active');
    this.loadItems();
  },

  onSearch(value) {
    this.searchQuery = value;
    clearTimeout(this._searchTimer);
    this._searchTimer = setTimeout(() => this.loadItems(), 300);
  },

  async openModal(itemId) {
    const modal = document.getElementById('library-modal');
    const titleEl = document.getElementById('library-modal-title');

    document.getElementById('lib-edit-id').value = '';
    document.getElementById('lib-title').value = '';
    document.getElementById('lib-url').value = '';
    document.getElementById('lib-desc').value = '';
    document.getElementById('lib-category').value = 'project';
    document.getElementById('lib-tags').value = '';

    if (itemId) {
      titleEl.textContent = 'Edit Item';
      try {
        const item = await API.request(`/library/${itemId}`);
        document.getElementById('lib-edit-id').value = item.id;
        document.getElementById('lib-title').value = item.title;
        document.getElementById('lib-url').value = item.url || '';
        document.getElementById('lib-desc').value = item.description || '';
        document.getElementById('lib-category').value = item.category;
        let tags = [];
        try { tags = JSON.parse(item.tags || '[]'); } catch(e) {}
        document.getElementById('lib-tags').value = tags.join(', ');
      } catch (error) {
        showToast('Failed to load item', 'error');
        return;
      }
    } else {
      titleEl.textContent = 'Add to Library';
    }

    modal.classList.add('active');
  },

  closeModal() {
    document.getElementById('library-modal').classList.remove('active');
  },

  async saveItem() {
    const id = document.getElementById('lib-edit-id').value;
    const tagsStr = document.getElementById('lib-tags').value;
    const tags = tagsStr ? tagsStr.split(',').map(t => t.trim()).filter(Boolean) : [];

    const data = {
      title: document.getElementById('lib-title').value,
      url: document.getElementById('lib-url').value,
      description: document.getElementById('lib-desc').value,
      category: document.getElementById('lib-category').value,
      tags
    };

    if (!data.title.trim()) {
      showToast('Title is required', 'error');
      return;
    }

    try {
      if (id) {
        await API.updateLibraryItem(id, data);
        showToast('Item updated', 'success');
      } else {
        await API.createLibraryItem(data);
        showToast('Item added to library', 'success');
      }
      this.closeModal();
      this.loadItems();
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async deleteItem(id) {
    if (!confirm('Remove this item from library?')) return;
    try {
      await API.deleteLibraryItem(id);
      showToast('Item removed', 'success');
      this.loadItems();
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
