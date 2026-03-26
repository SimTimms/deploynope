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
const STALE_THRESHOLD_MS = 7 * 24 * 60 * 60 * 1000; // 1 week

// Ensure state directory and file exist
if (!fs.existsSync(STATE_DIR)) fs.mkdirSync(STATE_DIR, { recursive: true });
if (!fs.existsSync(STATE_FILE)) {
  fs.writeFileSync(STATE_FILE, JSON.stringify({ version: 1, agents: {}, stagingClaim: null, warnings: [], activity: [] }));
}

function readState() {
  try {
    const raw = fs.readFileSync(STATE_FILE, 'utf8');
    const state = JSON.parse(raw);

    // Mark stale agents based on last real activity (git action timestamp).
    // For hook-registered agents, lastSeenAt reflects real session activity.
    // For scanned agents, lastSeenAt is just the scan time — use the action
    // timestamp (last commit time on the branch) instead.
    const now = Date.now();
    for (const [id, agent] of Object.entries(state.agents || {})) {
      const actionTime = agent.lastAction && agent.lastAction.timestamp
        ? new Date(agent.lastAction.timestamp).getTime()
        : 0;
      const lastSeen = new Date(agent.lastSeenAt).getTime();
      const lastActivity = agent.scanned ? actionTime : Math.max(actionTime, lastSeen);
      agent.stale = !lastActivity || (now - lastActivity) > STALE_THRESHOLD_MS;
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

// Watch state directory for changes (watching the file directly breaks on macOS
// when atomic writes replace the inode via mv)
let debounceTimer = null;
fs.watch(STATE_DIR, (eventType, filename) => {
  if (filename === 'dashboard-state.json') {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(broadcastState, 100);
  }
});

// Remove an agent — optionally removing its git worktree too
function removeAgent(agentId, removeWorktree, force) {
  const state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  const agent = (state.agents || {})[agentId];
  if (!agent) return { ok: false, error: 'Agent not found' };

  const result = { ok: true, id: agentId, worktreeRemoved: false };
  const cwd = agent.cwd || '';

  if (removeWorktree && cwd) {
    try {
      const gitDir = require('child_process')
        .execSync('git rev-parse --git-dir', { cwd, encoding: 'utf8', timeout: 5000 })
        .trim();
      const isWorktree = gitDir.includes('/worktrees/');

      if (isWorktree) {
        const commonDir = require('child_process')
          .execSync('git rev-parse --git-common-dir', { cwd, encoding: 'utf8', timeout: 5000 })
          .trim();
        const mainRepo = path.resolve(cwd, commonDir, '..');

        const status = require('child_process')
          .execSync('git status --porcelain', { cwd, encoding: 'utf8', timeout: 5000 })
          .trim();

        if (status && !force) {
          return { ok: false, error: 'Worktree has uncommitted changes', dirty: true, status };
        }

        const forceFlag = force ? ' --force' : '';
        require('child_process')
          .execSync(`git worktree remove${forceFlag} "${cwd}"`, { cwd: mainRepo, encoding: 'utf8', timeout: 10000 });
        result.worktreeRemoved = true;
      } else {
        result.worktreeRemoved = false;
        result.note = 'Not a worktree — only removed dashboard entry';
      }
    } catch (e) {
      if (e.message && e.message.includes('ENOENT') || (e.stderr && e.stderr.includes('is not a working tree'))) {
        result.worktreeRemoved = false;
        result.note = 'Path no longer exists — removed dashboard entry only';
      } else {
        return { ok: false, error: e.message || String(e) };
      }
    }
  }

  delete state.agents[agentId];
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));

  return result;
}

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

  // Delete agent endpoint
  const deleteMatch = req.url.match(/^\/api\/agents\/([^/?]+)(\?.*)?$/);
  if (deleteMatch && req.method === 'DELETE') {
    const agentId = decodeURIComponent(deleteMatch[1]);
    const url = new URL(req.url, `http://${req.headers.host}`);
    const removeWt = url.searchParams.get('removeWorktree') === 'true';
    const forceWt = url.searchParams.get('force') === 'true';

    const result = removeAgent(agentId, removeWt, forceWt);

    if (!result.ok && result.dirty && !forceWt) {
      res.writeHead(409, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify(result));
      return;
    }

    const status = result.ok ? 200 : 400;
    res.writeHead(status, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify(result));
    return;
  }

  // Scan endpoint
  if (req.url === '/api/scan' && req.method === 'POST') {
    const scanScript = path.join(__dirname, 'scan.sh');
    try {
      const output = require('child_process')
        .execSync(`bash "${scanScript}"`, { encoding: 'utf8', timeout: 30000, cwd: path.join(__dirname, '..') });
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: true, output }));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ok: false, error: e.message || String(e) }));
    }
    return;
  }

  // CORS preflight for DELETE
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
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
