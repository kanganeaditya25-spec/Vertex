/* === Settings Page === */
const SettingsPage = {
  async render() {
    const container = document.getElementById('page-content');
    container.innerHTML = '<div class="loading-spinner"></div>';

    try {
      const settings = await API.getSettings();

      container.innerHTML = `
        <div style="max-width: 640px;">

          <div class="settings-section">
            <h3>🔔 Notifications</h3>
            <div class="settings-row">
              <div>
                <div class="settings-label">Push Notifications</div>
                <div class="settings-desc">Receive task reminders and daily planning alerts</div>
              </div>
              <div class="toggle ${settings.notificationsEnabled ? 'active' : ''}" id="notifications-toggle" onclick="SettingsPage.toggleNotifications()"></div>
            </div>
            <div class="settings-row">
              <div>
                <div class="settings-label">Morning Reminder</div>
                <div class="settings-desc">Get a summary of today's tasks</div>
              </div>
              <select class="form-select" style="width: auto;" id="morning-hour" onchange="SettingsPage.updateReminderHours()">
                ${Array.from({length: 24}, (_, i) => `<option value="${i}" ${i === settings.morningReminderHour ? 'selected' : ''}>${String(i).padStart(2,'0')}:00</option>`).join('')}
              </select>
            </div>
            <div class="settings-row">
              <div>
                <div class="settings-label">Evening Reminder</div>
                <div class="settings-desc">Reminder to plan tomorrow's tasks</div>
              </div>
              <select class="form-select" style="width: auto;" id="evening-hour" onchange="SettingsPage.updateReminderHours()">
                ${Array.from({length: 24}, (_, i) => `<option value="${i}" ${i === settings.eveningReminderHour ? 'selected' : ''}>${String(i).padStart(2,'0')}:00</option>`).join('')}
              </select>
            </div>
          </div>

          <div class="settings-section">
            <h3>🤖 AI Reports (Gemini)</h3>
            <div class="settings-row" style="flex-direction: column; align-items: stretch;">
              <div style="margin-bottom: var(--space-3);">
                <div class="settings-label">Gemini API Key</div>
                <div class="settings-desc">Get a free key from <a href="https://aistudio.google.com/" target="_blank">Google AI Studio</a></div>
              </div>
              <div style="display: flex; gap: var(--space-3);">
                <input type="password" class="form-input" id="gemini-key-input" placeholder="${settings.geminiKeySet ? '••••••••••••••••' : 'Paste your API key here'}" style="flex:1;">
                <button class="btn btn-primary" onclick="SettingsPage.saveGeminiKey()">Save Key</button>
              </div>
              ${settings.geminiKeySet ? '<span style="font-size: var(--text-xs); color: var(--success); margin-top: var(--space-2); display: block;">✓ API key is configured</span>' : ''}
            </div>
          </div>

          <div class="settings-section">
            <h3>🔒 Security</h3>
            <div class="settings-row" style="flex-direction: column; align-items: stretch;">
              <div class="settings-label" style="margin-bottom: var(--space-3);">Change PIN</div>
              <div style="display: flex; gap: var(--space-3); align-items: flex-end;">
                <div style="flex:1;">
                  <label class="form-label">Current PIN</label>
                  <input type="password" class="form-input" id="current-pin" maxlength="6" inputmode="numeric" placeholder="••••">
                </div>
                <div style="flex:1;">
                  <label class="form-label">New PIN</label>
                  <input type="password" class="form-input" id="new-pin" maxlength="6" inputmode="numeric" placeholder="••••">
                </div>
                <button class="btn btn-primary" onclick="SettingsPage.changePin()" style="margin-bottom: 0;">Update</button>
              </div>
            </div>
            <div class="settings-row">
              <div>
                <div class="settings-label">Lock Dashboard</div>
                <div class="settings-desc">Log out and require PIN to access</div>
              </div>
              <button class="btn btn-secondary" onclick="SettingsPage.lockDashboard()">🔒 Lock</button>
            </div>
          </div>

          <div class="settings-section">
            <h3>📦 Data</h3>
            <div class="settings-row">
              <div>
                <div class="settings-label">Export All Data</div>
                <div class="settings-desc">Download all tasks, library items, and goals as JSON</div>
              </div>
              <button class="btn btn-secondary" onclick="SettingsPage.exportData()">📥 Export</button>
            </div>
          </div>

        </div>
      `;
    } catch (error) {
      container.innerHTML = `<div class="empty-state"><h3>Error loading settings</h3><p>${error.message}</p></div>`;
    }
  },

  async toggleNotifications() {
    const toggle = document.getElementById('notifications-toggle');
    const isActive = toggle.classList.contains('active');

    if (!isActive) {
      // Enable — request permission first
      if ('Notification' in window) {
        const perm = await Notification.requestPermission();
        if (perm !== 'granted') {
          showToast('Notification permission denied by browser', 'error');
          return;
        }
      }

      // Subscribe to push
      try {
        await this.subscribeToPush();
        toggle.classList.add('active');
        await API.updateSettings({ notificationsEnabled: true });
        showToast('Notifications enabled!', 'success');
      } catch (error) {
        showToast('Failed to enable notifications: ' + error.message, 'error');
      }
    } else {
      try {
        const registration = await navigator.serviceWorker?.ready;
        const subscription = await registration?.pushManager?.getSubscription();
        if (subscription) {
          await API.unsubscribePush(subscription);
          await subscription.unsubscribe();
        }
      } catch (error) {
        console.warn('[Notifications] Could not remove browser subscription:', error.message);
      }

      toggle.classList.remove('active');
      await API.updateSettings({ notificationsEnabled: false });
      showToast('Notifications disabled', 'info');
    }
  },

  async subscribeToPush() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      throw new Error('Push notifications not supported in this browser');
    }

    const registration = await navigator.serviceWorker.ready;
    const { publicKey } = await API.getVapidKey();

    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(publicKey)
    });

    await API.subscribePush(subscription);
  },

  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  },

  async updateReminderHours() {
    const morning = parseInt(document.getElementById('morning-hour').value);
    const evening = parseInt(document.getElementById('evening-hour').value);
    try {
      await API.updateSettings({ morningReminderHour: morning, eveningReminderHour: evening });
      showToast('Reminder times updated', 'success');
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async saveGeminiKey() {
    const key = document.getElementById('gemini-key-input').value;
    if (!key.trim()) {
      showToast('Please enter an API key', 'error');
      return;
    }
    try {
      await API.updateSettings({ geminiKey: key });
      showToast('Gemini API key saved!', 'success');
      this.render(); // Refresh to show status
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  async changePin() {
    const currentPin = document.getElementById('current-pin').value;
    const newPin = document.getElementById('new-pin').value;

    if (!currentPin || !newPin) {
      showToast('Please fill in both fields', 'error');
      return;
    }
    if (newPin.length < 4) {
      showToast('New PIN must be at least 4 digits', 'error');
      return;
    }

    try {
      const result = await API.changePin(currentPin, newPin);
      API.setToken(result.token);
      showToast('PIN changed successfully', 'success');
      document.getElementById('current-pin').value = '';
      document.getElementById('new-pin').value = '';
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  lockDashboard() {
    API.clearToken();
    window.location.hash = '#login';
    showToast('Dashboard locked', 'info');
  },

  async exportData() {
    try {
      const data = await API.exportData();
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `productivity-export-${getTodayStr()}.json`;
      a.click();
      URL.revokeObjectURL(url);
      showToast('Data exported!', 'success');
    } catch (error) {
      showToast('Export failed: ' + error.message, 'error');
    }
  }
};
