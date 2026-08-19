const assert = require('node:assert/strict');
process.env.VERCEL = '1';
const app = require('../server');

const server = app.listen(0, async () => {
  const port = server.address().port;
  const base = `http://127.0.0.1:${port}`;
  try {
    const status = await fetch(`${base}/api/auth/status`);
    assert.equal(status.status, 200);
    const initial = await status.json();
    assert.equal(initial.accountExists, false);

    const signup = await fetch(`${base}/api/auth/signup`, {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({name: 'Audit User', email: 'audit@example.com', password: 'auditpass123'}),
    });
    assert.equal(signup.status, 200);
    const signupBody = await signup.json();
    assert.equal(typeof signupBody.token, 'string');

    const tasks = await fetch(`${base}/api/tasks`, {
      headers: {authorization: `Bearer ${signupBody.token}`},
    });
    assert.equal(tasks.status, 200);
    assert.ok(Array.isArray(await tasks.json()));

    const invalidLogin = await fetch(`${base}/api/auth/email-login`, {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({email: 'audit@example.com', password: 'wrongpass'}),
    });
    assert.equal(invalidLogin.status, 401);

    console.log('Express auth workflow passed');
  } finally {
    server.close();
  }
});
