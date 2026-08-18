/* === Client-Side Router & App Controller === */
const App = {
  routes: {
    '#login': LoginPage,
    '#dashboard': DashboardPage,
    '#tasks': TasksPage,
    '#library': LibraryPage,
    '#reports': ReportsPage,
    '#settings': SettingsPage
  },

  async init() {
    // Register service worker for PWA and Push Notifications
    this.registerServiceWorker();

    // Check auth status
    try {
      const status = await API.authStatus();
      if (!status.isSetup) {
        window.location.hash = '#login';
      } else if (!API.token) {
        window.location.hash = '#login';
      } else if (window.location.hash === '' || window.location.hash === '#login') {
        window.location.hash = '#dashboard';
      }
    } catch (error) {
      window.location.hash = '#login';
    }

    // Bind hash change routing
    window.addEventListener('hashchange', () => this.route());
    
    // Initial routing
    this.route();
  },

  route() {
    const hash = window.location.hash || '#dashboard';
    
    // Auth guard
    if (hash !== '#login' && !API.token) {
      window.location.hash = '#login';
      return;
    }

    const page = this.routes[hash];
    if (!page) {
      window.location.hash = '#dashboard';
      return;
    }

    // Render layout if not login page
    if (hash === '#login') {
      page.render();
    } else {
      this.ensureAppLayout();
      this.setActiveNav(hash);
      page.render();
    }
  },

  ensureAppLayout() {
    const appEl = document.getElementById('app');
    if (appEl.querySelector('.app-layout')) return;

    appEl.innerHTML = `
      <div class="app-layout">
        <!-- Sidebar overlay for mobile -->
        <div class="sidebar-overlay" id="sidebar-overlay" onclick="App.toggleSidebar(false)"></div>

        <aside class="sidebar" id="sidebar">
          <div class="sidebar-header">
            <div class="sidebar-logo">
              <div class="logo-icon">⚡</div>
              <h1>Productivity</h1>
            </div>
          </div>
          <nav class="sidebar-nav">
            <button class="nav-item" data-hash="#dashboard" onclick="window.location.hash='#dashboard'">
              <span class="nav-icon">📊</span> Dashboard
            </button>
            <button class="nav-item" data-hash="#tasks" onclick="window.location.hash='#tasks'">
              <span class="nav-icon">📋</span> Tasks
            </button>
            <button class="nav-item" data-hash="#library" onclick="window.location.hash='#library'">
              <span class="nav-icon">📚</span> Personal Library
            </button>
            <button class="nav-item" data-hash="#reports" onclick="window.location.hash='#reports'">
              <span class="nav-icon">📈</span> Reports & Goals
            </button>
            <button class="nav-item" data-hash="#settings" onclick="window.location.hash='#settings'">
              <span class="nav-icon">⚙️</span> Settings
            </button>
          </nav>
          <div class="sidebar-footer">
            <button class="nav-item" onclick="SettingsPage.lockDashboard()">
              <span class="nav-icon">🔒</span> Lock
            </button>
          </div>
        </aside>

        <main class="main-content">
          <header class="page-header">
            <button class="mobile-menu-btn" onclick="App.toggleSidebar(true)">☰</button>
            <h2 id="page-title">Dashboard</h2>
            <div class="page-header-actions">
              <!-- Quick Actions -->
              <button class="btn btn-secondary btn-sm" onclick="window.location.hash='#tasks'; TasksPage.openModal();">+ Quick Task</button>
            </div>
          </header>
          <div class="page-body" id="page-content"></div>
        </main>
      </div>
    `;
  },

  setActiveNav(hash) {
    document.querySelectorAll('.nav-item').forEach(item => {
      if (item.getAttribute('data-hash') === hash) {
        item.classList.add('active');
      } else {
        item.classList.remove('active');
      }
    });

    // Close sidebar on mobile after navigation
    this.toggleSidebar(false);

    // Update page title text
    const titleEl = document.getElementById('page-title');
    if (titleEl) {
      const titles = {
        '#dashboard': 'Dashboard',
        '#tasks': 'Tasks',
        '#library': 'Personal Library',
        '#reports': 'Reports & Goals',
        '#settings': 'Settings'
      };
      titleEl.textContent = titles[hash] || 'Productivity';
    }
  },

  toggleSidebar(show) {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebar-overlay');
    if (sidebar && overlay) {
      if (show) {
        sidebar.classList.add('open');
        overlay.classList.add('active');
      } else {
        sidebar.classList.remove('open');
        overlay.classList.remove('active');
      }
    }
  },

  async registerServiceWorker() {
    if ('serviceWorker' in navigator) {
      try {
        const registration = await navigator.serviceWorker.register('/sw.js');
        console.log('[PWA] Service Worker registered with scope:', registration.scope);
      } catch (error) {
        console.error('[PWA] Service Worker registration failed:', error);
      }
    }
  }
};

// Initialize App
document.addEventListener('DOMContentLoaded', () => App.init());
