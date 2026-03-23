#!/usr/bin/env node
// DeployNOPE Dashboard Server
// Zero-dependency Node.js server with SSE for real-time state updates.
// Usage: node dashboard/server.js [port]

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.argv[2] || '9876', 10);
const STATE_DIR = path.join(require('os').homedir(), '.deploynope');
const STATE_FILE = path.join(STATE_DIR, 'dashboard-state.json');
const DASHBOARD_HTML = path.join(__dirname, 'index.html');
const STALE_THRESHOLD_MS = 5 * 60 * 1000; // 5 minutes

// Ensure state directory and file exist
if (!fs.existsSync(STATE_DIR)) fs.mkdirSync(STATE_DIR, { recursive: true });
if (!fs.existsSync(STATE_FILE)) {
  fs.writeFileSync(STATE_FILE, JSON.stringify({ version: 1, agents: {}, stagingClaim: null, warnings: [], activity: [] }));
}

function readState() {
  try {
    const raw = fs.readFileSync(STATE_FILE, 'utf8');
    const state = JSON.parse(raw);

    // Mark stale agents
    const now = Date.now();
    for (const [id, agent] of Object.entries(state.agents || {})) {
      const lastSeen = new Date(agent.lastSeenAt).getTime();
      agent.stale = (now - lastSeen) > STALE_THRESHOLD_MS;
    }

    return state;
  } catch (e) {
    return { version: 1, agents: {}, stagingClaim: null, warnings: [], activity: [] };
  }
}

// SSE clients
const clients = new Set();

function broadcastState() {
  const state = readState();
  const data = `data: ${JSON.stringify(state)}\n\n`;
  for (const res of clients) {
    try { res.write(data); } catch (e) { clients.delete(res); }
  }
}

// Watch state file for changes
let debounceTimer = null;
fs.watch(STATE_FILE, () => {
  // Debounce rapid writes (multiple hooks firing close together)
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(broadcastState, 100);
});

const server = http.createServer((req, res) => {
  // SSE endpoint
  if (req.url === '/api/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });

    // Send current state immediately
    const state = readState();
    res.write(`data: ${JSON.stringify(state)}\n\n`);

    clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }

  // State API (for polling fallback)
  if (req.url === '/api/state') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify(readState()));
    return;
  }

  // Serve dashboard HTML
  if (req.url === '/' || req.url === '/index.html') {
    try {
      const html = fs.readFileSync(DASHBOARD_HTML, 'utf8');
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(html);
    } catch (e) {
      res.writeHead(500);
      res.end('Dashboard HTML not found');
    }
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`DeployNOPE Dashboard running at http://localhost:${PORT}`);
  console.log(`Watching: ${STATE_FILE}`);
  console.log('Press Ctrl+C to stop.');
});
