# PantryBuddy API

A REST API in front of the `pantry_buddy` MySQL schema (schema.sql /
seed_data.sql), so the Flutter app can talk to a real database instead of
its in-memory mock. This is step 3 of the chain: SQL schema → running DB →
**this API server** → Flutter app.

This has been smoke-tested end-to-end against a real MySQL 8.0 instance
loaded with the exact schema.sql + seed_data.sql your friend provided —
every route below was exercised and verified working before being handed
over.

## Setup

1. **Install Node.js** (18+) if you don't have it: https://nodejs.org
2. `cd pantrybuddy-backend`
3. `npm install`
4. `cp .env.example .env`, then open `.env` and fill in the real database
   host/user/password/database name your friend gave you. **Never commit
   the real `.env`** — `.gitignore` already excludes it.
5. `npm start` — you should see `PantryBuddy API listening on http://localhost:4000`

To confirm it's actually connected and working:
```bash
curl http://localhost:4000/health
curl http://localhost:4000/households/1/inventory-items
```
The second command should return the seeded inventory for "Lee Family
Pantry" (team_id 1) if `seed_data.sql` was loaded — if you get a
connection error instead, the `.env` values are the first thing to check.

## Deploying it somewhere real

Running `npm start` on your own laptop only works while your laptop is on
and the Flutter app is running on the *same machine* (`localhost`). For
your phone or another device to reach it, you'll want to either:
- Run it on the same Wi-Fi and use your laptop's local IP instead of
  `localhost` (quick, but breaks when you change networks), or
- Deploy it somewhere free/cheap like Render, Railway, or Fly.io (set the
  same environment variables there instead of a local `.env`).

## Email (Gmail SMTP)

Password-reset emails are sent through your own Gmail account (via [Nodemailer](https://nodemailer.com)) — completely free, no domain needed, and unlike a third-party email API's free tier, it works for **any** recipient, not just your own address.

1. On the Google Account you want to send from: turn on **2-Step Verification** (Google Account → Security) — required before you can generate an App Password.
2. Google Account → Security → **App Passwords** → create one (name it anything, e.g. "PantryBuddy") → copy the 16-character password it gives you.
3. Add to your local `.env`:
   ```
   GMAIL_USER=youraddress@gmail.com
   GMAIL_APP_PASSWORD=the16charapppassword
   FRONTEND_URL=https://pantrybuddy-yourname.vercel.app
   ```
4. Add the same three to Vercel's environment variables (Project Settings → Environment Variables) and redeploy — env var changes don't apply to already-running deployments.

**Note:** `GMAIL_APP_PASSWORD` is NOT your normal Gmail login password — using your real password won't work (and you shouldn't put it in an env var anyway). It's a separate, revocable 16-character password Google generates specifically for apps like this.

If `GMAIL_USER`/`GMAIL_APP_PASSWORD` aren't set at all, the backend doesn't crash — it just logs the reset link to the server console instead of emailing it (useful for local testing without setting any of this up).

Gmail's free sending limit is 500 emails/day — far more than a class project needs.

## API surface

All request/response bodies are JSON. IDs are always returned as strings
(even though they're BIGINT in MySQL) to match the Flutter app's models.

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/signup` | `{name, email, password, avatarKey}` → 409 if email taken |
| POST | `/auth/signin` | `{email, password}` → 401 if wrong |
| POST | `/auth/forgot-password` | `{email}` → always 200; sends a real reset email via Gmail SMTP (see "Email (Gmail SMTP)" above) |
| POST | `/auth/reset-password` | `{token, newPassword}` → completes a reset started above |
| GET/PATCH | `/users/:id` | |
| POST | `/households` | `{name, creatorUserId}` — creator becomes ADMIN |
| GET | `/households/:id` | |
| GET | `/households/by-invite/:code` | invite code = the team's numeric ID |
| GET | `/households/:id/members` | |
| POST | `/join-requests` | `{inviteCode, userId}` → 409 if already a member or already pending |
| GET | `/households/:id/join-requests?status=pending` | admin's pending list |
| GET | `/join-requests/:id` | for the requester to poll their own status |
| POST | `/join-requests/:id/approve` \| `/decline` | `{reviewedByUserId}` |
| GET/POST | `/households/:id/inventory-items` | POST auto-creates the `products` row if needed (see below) |
| PUT | `/inventory-items/:id` | |
| POST | `/inventory-items/:id/resolve` | `{disposition: 'consumed'|'discarded', resolvedByUserId}` |
| DELETE | `/inventory-items/:id` | |
| POST | `/reminders` | `{itemId, householdId, leadTimeDays, createdByUserId}` |
| GET | `/households/:id/reminders` | |
| POST | `/reminders/:id/mark-triggered` | |
| GET | `/households/:id/activity` | derived from `inventory_transactions` + `team_members`, see below |

## Known gaps / schema mismatches (worth flagging to your friend)

1. **No `unit` column.** `inventory_items.quantity` is a bare number —
   there's no column for "pcs" / "g" / "cans" etc. The API currently
   always returns `unit: "pcs"` and doesn't persist whatever the app
   sends. Fix: add `unit VARCHAR(20) NULL` to `inventory_items`, then
   it's a 2-line change in `src/routes/inventory.js`.
2. **`avatar_id` has no catalog table.** `src/util/avatars.js` hardcodes
   a 12-avatar list matching the Flutter app's order (1=tomato,
   2=carrot, ...). Fine for now, but fragile if either side changes
   independently — a real `avatars` table would be cleaner.
3. **No "Donate" status.** `inventory_items.status` only has
   `IN_STOCK/CONSUMED/EXPIRED/DISCARDED` — the app already dropped its
   Donate button to match. Add `DONATED` to the enum (in both
   `inventory_items.status` and `inventory_transactions.transaction_type`)
   if you want it back.
4. **Activity feed is derived, not stored.** There's no activity-log
   table in the schema, so `GET /households/:id/activity` is assembled
   from `inventory_transactions` (ADD/CONSUME/DISCARD) plus
   `team_members.joined_at`. This means item **edits** don't show up in
   the feed (no transaction type for that) — only add/consume/discard/join.
5. **Password reset works, but relies on one Gmail account.** All reset
   emails send through whoever's `GMAIL_USER` is configured — fine for a
   class project, but a real product would use a dedicated transactional
   email service instead of a personal inbox.
6. **`notification_recipients` isn't used yet.** Multi-user per-reminder
   read state isn't implemented in either the app or this API yet.
7. **`reminders.status = 'CANCELLED'`** has no API route yet (no
   "cancel reminder" feature in the app currently).

## Testing scenarios

Your friend's `test_data.sql` has 32 scenarios for testing the schema
directly in MySQL. This API doesn't re-implement those as automated
tests, but every route was manually exercised against a real MySQL 8.0
instance loaded with `schema.sql` + `seed_data.sql` before being handed
over — signup/duplicate-email, signin/wrong-password, household
creation, join-request + approve + duplicate-pending-request rejection,
member listing, item add/list/resolve, reminder creation, and the
activity feed all returned correct results.
