# Streak Buddies 🫏🦝🐭🐮🐼

Live: https://itsmas.github.io/streak-tracker/

A minimalist, cute exercise streak tracker. Five animal buddies cheer every
workout, wander across the screen now and then, and make little sounds when
poked.

## Files

- `app.html` — the whole app as a single self-contained fragment (source of truth,
  also what gets published as a Claude artifact for previews)
- `build.sh` — wraps `app.html` into `index.html` (full standalone page)
- `index.html` — generated; ready for GitHub Pages / any static host
- `manifest.webmanifest`, `sw.js` — PWA install + offline support when self-hosted;
  the service worker also shows the angry-raccoon push notification
- `.github/workflows/angry-push.yml`, `.github/send-push.js` — daily web push
  that wakes the service worker (works with the app closed and the phone locked)

## Features

- Daily log with optional plank duration (min:sec) and a migraine checkbox —
  a migraine day is skipped without breaking the streak, but doesn't increase it
- Plank line chart over time with 7D / 14D / 30D / All ranges and tap tooltips
- Any past day is editable from the calendar or week strip: mark exercise
  (with plank time), migraine, or clear it
- Streak counter, week strip, monthly calendar, milestone badges
  (3/7/14/21/30/50/75/100) and stats — minimal text
- Celebrations with confetti, haptics, and synthesized animal sounds;
  buddies occasionally wander across the screen (tap them!)
- Optional reminder notification at a configurable time (fires while the app
  is open or installed)
- Data lives in `localStorage` on the phone — no accounts, no server

## Install on Android

Host the repo with GitHub Pages (Settings → Pages → deploy from `main`), open the
URL in Chrome, then **⋮ → Add to Home screen**. It installs like an app, works
offline, and can show notifications.

## Angry raccoon (lock-screen nag) 😡🦝

Every evening a GitHub Actions cron sends a web push to the phone. The push
wakes the service worker even when the app is closed and the phone is locked;
the worker checks the day log (mirrored into IndexedDB) and shows either a big
angry raccoon (nothing logged today) or a quiet "streak safe" note. A migraine
day counts as logged.

One-time setup:

1. In the installed app: **Settings → Angry raccoon** → allow notifications →
   tap **Copy** (this copies your phone's push subscription).
2. On GitHub: repo **Settings → Secrets and variables → Actions** → add secret
   `PUSH_SUBSCRIPTION` → paste the copied code.
3. Add a second secret `VAPID_PRIVATE_KEY` with the private key that pairs with
   the public key in `app.html` (kept outside the repo; regenerate a pair with
   `npx web-push generate-vapid-keys` if lost — then update the public key in
   `app.html` + `.github/send-push.js` and redo step 1-2).
4. Test it: **Actions → Angry raccoon push → Run workflow**. The raccoon should
   appear on the phone within seconds.

Notes: the schedule in `angry-push.yml` is UTC (17:00 UTC ≈ 8pm Vilnius summer
time) and GitHub cron can run 15-30 min late. If pushes stop arriving (e.g.
after clearing site data), re-toggle Angry raccoon and re-paste the secret.

## Develop

Edit `app.html`, then run `sh build.sh` to regenerate `index.html`.
