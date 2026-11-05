/*
 Yetties Bank backend — Cloudflare Worker + D1 (Phase 1 of the Level 3 roadmap)

 What it does:
 - User accounts with salted, server-side password hashing (PBKDF2)
 - Session tokens for the app (Bearer auth)
 - Syncs accounts, transactions and goals between devices

 Endpoints:
   POST /api/signup   { email, password, name }        -> { token, user }
   POST /api/login    { email, password }              -> { token, user }
   GET  /api/data                                        -> full snapshot for the user
   PUT  /api/data    { accounts, transactions, goals }   -> replaces the snapshot
   GET  /             -> plain text status

 Setup (in the Cloudflare dashboard):
   1. Workers & Pages -> Create -> Worker -> name it "yetties-api" -> Deploy
   2. Workers & Pages -> D1 -> Create database -> name "yetties-db"
   3. Open the worker -> Settings -> Bindings -> add a D1 binding:
        variable name: DB    database: yetties-db
   4. Paste this file's contents into the worker editor -> Deploy
   5. In D1 console, run the schema below once:

 CREATE TABLE IF NOT EXISTS users (
   id INTEGER PRIMARY KEY AUTOINCREMENT,
   email TEXT UNIQUE NOT NULL,
   name TEXT NOT NULL,
   salt TEXT NOT NULL,
   hash TEXT NOT NULL,
   created_at INTEGER NOT NULL
 );
 CREATE TABLE IF NOT EXISTS sessions (
   token TEXT PRIMARY KEY,
   user_id INTEGER NOT NULL,
   created_at INTEGER NOT NULL
 );
 CREATE TABLE IF NOT EXISTS snapshots (
   user_id INTEGER PRIMARY KEY,
   data TEXT NOT NULL,
   updated_at INTEGER NOT NULL
 );
*/

const encoder = new TextEncoder();

/* The PWA (on pages.dev) calls this worker from a different origin, so CORS is required. */
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
};

function json(data, status) {
  return new Response(JSON.stringify(data), {
    status: status || 200,
    headers: { 'Content-Type': 'application/json', ...CORS }
  });
}

async function readBody(request) {
  try {
    return await request.json();
  } catch (e) {
    return null;
  }
}

/* PBKDF2-SHA256, 100k iterations. Salt is random per user, generated on signup. */
async function hashPassword(password, salt) {
  const key = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt: encoder.encode(salt), iterations: 100000 },
    key, 256
  );
  return [...new Uint8Array(bits)].map(b => b.toString(16).padStart(2, '0')).join('');
}

function newToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return [...bytes].map(b => b.toString(16).padStart(2, '0')).join('');
}

async function userFromRequest(request, env) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const row = await env.DB
    .prepare('SELECT u.id, u.email, u.name FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?')
    .bind(token)
    .first();
  return row || null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    if (url.pathname === '/' && request.method === 'GET') {
      return new Response('Yetties Bank API — running. Endpoints: /api/signup, /api/login, /api/data', {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    if (url.pathname === '/api/signup' && request.method === 'POST') {
      const body = await readBody(request);
      if (!body) return json({ error: 'Invalid request body.' }, 400);
      const email = String(body.email || '').trim().toLowerCase();
      const password = String(body.password || '');
      const name = String(body.name || '').trim();
      if (!name) return json({ error: 'Please enter your name.' }, 400);
      if (!email.includes('@') || !email.includes('.')) return json({ error: 'Please enter a valid email address.' }, 400);
      if (password.length < 6) return json({ error: 'Password must be at least 6 characters.' }, 400);

      const existing = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
      if (existing) return json({ error: 'An account with this email already exists.' }, 409);

      const salt = newToken().slice(0, 32);
      const hash = await hashPassword(password, salt);
      const result = await env.DB
        .prepare('INSERT INTO users (email, name, salt, hash, created_at) VALUES (?, ?, ?, ?, ?)')
        .bind(email, name, salt, hash, Date.now())
        .run();
      const token = newToken();
      await env.DB.prepare('INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)')
        .bind(token, result.meta.last_row_id, Date.now())
        .run();
      return json({ token: token, user: { name: name, email: email } });
    }

    if (url.pathname === '/api/login' && request.method === 'POST') {
      const body = await readBody(request);
      if (!body) return json({ error: 'Invalid request body.' }, 400);
      const email = String(body.email || '').trim().toLowerCase();
      const password = String(body.password || '');
      const user = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first();
      if (!user) return json({ error: 'Incorrect email or password.' }, 401);
      const hash = await hashPassword(password, user.salt);
      if (hash !== user.hash) return json({ error: 'Incorrect email or password.' }, 401);
      const token = newToken();
      await env.DB.prepare('INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)')
        .bind(token, user.id, Date.now())
        .run();
      return json({ token: token, user: { name: user.name, email: user.email } });
    }

    if (url.pathname === '/api/data') {
      const user = await userFromRequest(request, env);
      if (!user) return json({ error: 'Not signed in.' }, 401);

      if (request.method === 'GET') {
        const snap = await env.DB.prepare('SELECT data, updated_at FROM snapshots WHERE user_id = ?')
          .bind(user.id)
          .first();
        if (!snap) return json({ data: null, updated_at: 0 });
        let data = null;
        try { data = JSON.parse(snap.data); } catch (e) { data = null; }
        return json({ data: data, updated_at: snap.updated_at });
      }

      if (request.method === 'PUT') {
        const body = await readBody(request);
        if (!body || typeof body !== 'object') return json({ error: 'Invalid request body.' }, 400);
        /* Only tracker-shaped data is accepted — never credentials or money instructions. */
        const safe = {
          accounts: Array.isArray(body.accounts) ? body.accounts : [],
          transactions: Array.isArray(body.transactions) ? body.transactions : [],
          goals: Array.isArray(body.goals) ? body.goals : [],
          hideBalances: !!body.hideBalances,
          monthlyBudget: typeof body.monthlyBudget === 'number' ? body.monthlyBudget : 3000
        };
        await env.DB
          .prepare('INSERT INTO snapshots (user_id, data, updated_at) VALUES (?, ?, ?) ' +
                   'ON CONFLICT(user_id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at')
          .bind(user.id, JSON.stringify(safe), Date.now())
          .run();
        return json({ ok: true });
      }
    }

    return json({ error: 'Not found.' }, 404);
  }
};