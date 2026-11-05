# Yetties Bank backend — setup guide

This is your own sync server (Cloudflare Worker + D1 database). Once it's
live and connected in the app, your accounts, transactions and goals back
up automatically and sync across every device you sign in on.

## 1. Create the database

1. dash.cloudflare.com → **Storage & Databases → D1** → **Create database**
2. Name: `yetties-db` → Create
3. Open it → **Console** tab → paste the contents of **schema.sql** → **Run**

## 2. Create the worker

1. **Workers & Pages → Create → Worker** → name: `yetties-api` → **Deploy**
2. Open the worker → **Edit code** → delete the starter code → paste the
   full contents of **worker.js** → **Deploy**
3. Worker → **Settings → Bindings → Add** → type **D1** →
   variable name: `DB` → database: `yetties-db` → Deploy again if asked

## 3. Find your API URL

On the worker's page, Cloudflare shows a URL like:

```
https://yetties-api.your-name.workers.dev
```

Copy it. Test it in Safari: open that URL — you should see
"Yetties Bank API — running."

## 4. Connect the app

Open Yetties Bank → **Profile → Cloud sync**:

1. Paste your API URL into **API URL**
2. Enter email + password, choose **Create account**, enter your name
3. Tap **Create cloud account**

From then on every change backs up automatically (a few seconds after you
make it). Use **Back up now** for an immediate save, **Restore from cloud**
to pull your data onto a new device, and **Sign out of cloud** to stop
syncing on that device. Your cloud backup is kept even if you erase local
data — sign in again and restore.

## Security notes

- Passwords are salted + hashed (PBKDF2-SHA256, 100k iterations) on the
  server — the app never stores or sends your password after login.
- Sessions are random 256-bit tokens.
- Only tracker-shaped data is accepted by the sync endpoint.
- HTTPS everywhere (both *.pages.dev and *.workers.dev).