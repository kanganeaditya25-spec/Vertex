process.env.VERCEL = '1';

const http = require('http');
const app = require('../server');

const server = http.createServer(app);
server.listen(0, async () => {
  const { port } = server.address();
  try {
    const response = await fetch(`http://127.0.0.1:${port}/`);
    const html = await response.text();
    if (response.status !== 200 || !html.includes('Productivity Dashboard')) {
      throw new Error(`Unexpected response: ${response.status}`);
    }
    console.log(JSON.stringify({ status: response.status, exportedApp: true, vercelMode: true }));
  } finally {
    server.close();
  }
});
