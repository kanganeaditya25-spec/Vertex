/* === API Client === */
const API = {
  baseUrl: '/api',
  token: localStorage.getItem('auth_token'),

  setToken(token) {
    this.token = token;
    localStorage.setItem('auth_token', token);
  },

  clearToken() {
    this.token = null;
    localStorage.removeItem('auth_token');
  },

  async request(path, options = {}) {
    const url = `${this.baseUrl}${path}`;
    const headers = { ...options.headers };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    // Don't set Content-Type for FormData (multer)
    if (!(options.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
      if (options.body && typeof options.body === 'object') {
        options.body = JSON.stringify(options.body);
      }
    }

    try {
      const res = await fetch(url, { ...options, headers });

      if (res.status === 401) {
        this.clearToken();
        window.location.hash = '#login';
        throw new Error('Session expired. Please log in again.');
      }

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.error || 'Request failed');
      }

      return data;
    } catch (error) {
      if (error.message === 'Session expired. Please log in again.') throw error;
      throw error;
    }
  },

  // Auth
  authStatus: () => API.request('/auth/status'),
  setupPin: (pin) => API.request('/auth/setup', { method: 'POST', body: { pin } }),
  login: (pin) => API.request('/auth/login', { method: 'POST', body: { pin } }),
  changePin: (currentPin, newPin) => API.request('/auth/change-pin', { method: 'POST', body: { currentPin, newPin } }),

  // Tasks
  getTasks: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return API.request(`/tasks${qs ? '?' + qs : ''}`);
  },
  getTask: (id) => API.request(`/tasks/${id}`),
  createTask: (data) => API.request('/tasks', { method: 'POST', body: data }),
  updateTask: (id, data) => API.request(`/tasks/${id}`, { method: 'PUT', body: data }),
  toggleTask: (id) => API.request(`/tasks/${id}/toggle`, { method: 'PATCH' }),
  deleteTask: (id) => API.request(`/tasks/${id}`, { method: 'DELETE' }),
  uploadAsset: (taskId, file) => {
    const formData = new FormData();
    formData.append('file', file);
    return API.request(`/tasks/${taskId}/assets`, { method: 'POST', body: formData });
  },
  deleteAsset: (taskId, assetId) => API.request(`/tasks/${taskId}/assets/${assetId}`, { method: 'DELETE' }),

  // Library
  getLibrary: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return API.request(`/library${qs ? '?' + qs : ''}`);
  },
  createLibraryItem: (data) => API.request('/library', { method: 'POST', body: data }),
  updateLibraryItem: (id, data) => API.request(`/library/${id}`, { method: 'PUT', body: data }),
  deleteLibraryItem: (id) => API.request(`/library/${id}`, { method: 'DELETE' }),

  // Goals
  getGoals: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return API.request(`/goals${qs ? '?' + qs : ''}`);
  },
  createGoal: (data) => API.request('/goals', { method: 'POST', body: data }),
  updateGoal: (id, data) => API.request(`/goals/${id}`, { method: 'PUT', body: data }),
  deleteGoal: (id) => API.request(`/goals/${id}`, { method: 'DELETE' }),

  // Reports
  getDailyReport: (date) => API.request(`/reports/daily${date ? '?date=' + date : ''}`),
  getMonthlyReport: (month, year) => API.request(`/reports/monthly?month=${month}&year=${year}`),
  getGoalsReport: () => API.request('/reports/goals'),

  // Notifications
  getVapidKey: () => API.request('/notifications/vapid-key'),
  subscribePush: (subscription) => API.request('/notifications/subscribe', { method: 'POST', body: { subscription } }),
  unsubscribePush: (subscription) => API.request('/notifications/unsubscribe', { method: 'POST', body: { subscription } }),

  // Settings
  getSettings: () => API.request('/settings'),
  updateSettings: (data) => API.request('/settings', { method: 'PUT', body: data }),
  exportData: () => API.request('/settings/export'),
};

/* === Toast notifications === */
function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

/* === Date helpers === */
function formatDate(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function formatDateShort(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function getTodayStr() {
  return new Date().toISOString().split('T')[0];
}
