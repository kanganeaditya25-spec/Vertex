/* === Login Page === */
const LoginPage = {
  isSetup: false,

  async render() {
    const app = document.getElementById('app');
    try {
      const status = await API.authStatus();
      this.isSetup = status.isSetup;
    } catch (e) {
      this.isSetup = false;
    }

    app.innerHTML = `
      <div class="login-page">
        <div class="login-card">
          <div class="logo-icon">⚡</div>
          <h2>${this.isSetup ? 'Welcome Back' : 'Set Up Your PIN'}</h2>
          <p>${this.isSetup ? 'Enter your PIN to unlock' : 'Create a 4-6 digit PIN to secure your dashboard'}</p>
          <div class="pin-input-group" id="pin-group">
            <input type="password" class="pin-digit" maxlength="1" inputmode="numeric" pattern="[0-9]" data-index="0">
            <input type="password" class="pin-digit" maxlength="1" inputmode="numeric" pattern="[0-9]" data-index="1">
            <input type="password" class="pin-digit" maxlength="1" inputmode="numeric" pattern="[0-9]" data-index="2">
            <input type="password" class="pin-digit" maxlength="1" inputmode="numeric" pattern="[0-9]" data-index="3">
            <input type="password" class="pin-digit" maxlength="1" inputmode="numeric" pattern="[0-9]" data-index="4">
            <input type="password" class="pin-digit" maxlength="1" inputmode="numeric" pattern="[0-9]" data-index="5">
          </div>
          <div class="login-error" id="login-error"></div>
          <button class="btn btn-primary btn-lg" style="width:100%" id="login-btn">
            ${this.isSetup ? 'Unlock' : 'Create PIN'}
          </button>
        </div>
      </div>
    `;

    this.bindEvents();
  },

  bindEvents() {
    const digits = document.querySelectorAll('.pin-digit');

    digits.forEach((input, idx) => {
      input.addEventListener('input', (e) => {
        const val = e.target.value.replace(/\D/g, '');
        e.target.value = val;
        if (val && idx < digits.length - 1) {
          digits[idx + 1].focus();
        }
      });

      input.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && !e.target.value && idx > 0) {
          digits[idx - 1].focus();
        }
        if (e.key === 'Enter') {
          document.getElementById('login-btn').click();
        }
      });

      input.addEventListener('paste', (e) => {
        e.preventDefault();
        const paste = (e.clipboardData || window.clipboardData).getData('text').replace(/\D/g, '');
        paste.split('').forEach((char, i) => {
          if (i < digits.length) {
            digits[i].value = char;
          }
        });
        const focusIdx = Math.min(paste.length, digits.length - 1);
        digits[focusIdx].focus();
      });
    });

    // Focus first digit
    digits[0].focus();

    document.getElementById('login-btn').addEventListener('click', () => this.submit());
  },

  async submit() {
    const digits = document.querySelectorAll('.pin-digit');
    const pin = Array.from(digits).map(d => d.value).join('');
    const errorEl = document.getElementById('login-error');

    if (pin.length < 4) {
      errorEl.textContent = 'Please enter at least 4 digits';
      return;
    }

    const btn = document.getElementById('login-btn');
    btn.disabled = true;
    btn.textContent = 'Please wait...';

    try {
      let result;
      if (this.isSetup) {
        result = await API.login(pin);
      } else {
        result = await API.setupPin(pin);
      }

      API.setToken(result.token);
      showToast(this.isSetup ? 'Welcome back!' : 'PIN created successfully!', 'success');
      window.location.hash = '#dashboard';
    } catch (error) {
      errorEl.textContent = error.message;
      digits.forEach(d => d.value = '');
      digits[0].focus();
    } finally {
      btn.disabled = false;
      btn.textContent = this.isSetup ? 'Unlock' : 'Create PIN';
    }
  }
};
