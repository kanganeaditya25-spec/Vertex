const baseUrl = 'http://localhost:3000';

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: { 'content-type': 'application/json', ...(options.headers || {}) }
  });
  const body = await response.json();
  return { status: response.status, body };
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

(async () => {
  const login = await request('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ pin: '123456' })
  });
  assert(login.status === 200 && login.body.token, `Login failed: ${JSON.stringify(login)}`);

  const auth = { authorization: `Bearer ${login.body.token}` };
  const settings = await request('/api/settings', { headers: auth });
  assert(settings.status === 200, `Settings GET failed: ${JSON.stringify(settings)}`);
  assert(settings.body.morningReminderHour === 9, `Unexpected morning hour: ${JSON.stringify(settings.body)}`);
  assert(settings.body.eveningReminderHour === 21, `Unexpected evening hour: ${JSON.stringify(settings.body)}`);
  assert(settings.body.notificationsEnabled === false, `Notifications should be opt-in: ${JSON.stringify(settings.body)}`);

  const invalidHour = await request('/api/settings', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ morningReminderHour: 24 })
  });
  assert(invalidHour.status === 400, `Invalid hour was accepted: ${JSON.stringify(invalidHour)}`);

  const invalidFlag = await request('/api/settings', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ notificationsEnabled: 'false' })
  });
  assert(invalidFlag.status === 400, `Invalid notification flag was accepted: ${JSON.stringify(invalidFlag)}`);

  const update = await request('/api/settings', {
    method: 'PUT',
    headers: auth,
    body: JSON.stringify({ morningReminderHour: 9, eveningReminderHour: 21, notificationsEnabled: false })
  });
  assert(update.status === 200 && update.body.success, `Valid settings update failed: ${JSON.stringify(update)}`);

  const protectedWithoutToken = await request('/api/settings');
  assert(protectedWithoutToken.status === 401, `Protected route was accessible without a token: ${JSON.stringify(protectedWithoutToken)}`);

  console.log(JSON.stringify({
    login: login.status,
    settings: settings.body,
    invalidHour: invalidHour.status,
    invalidFlag: invalidFlag.status,
    update: update.status,
    protectedWithoutToken: protectedWithoutToken.status
  }, null, 2));
})().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
