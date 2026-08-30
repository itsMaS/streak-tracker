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
- `manifest.webmanifest`, `sw.js` — PWA install + offline support when self-hosted

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
- Profile: set your name and a picture (pick an emoji buddy or use a photo,
  auto-cropped and stored locally) from the avatar button in the header
- Optional reminder notification at a configurable time (fires while the app
  is open or installed)
- Data lives in `localStorage` on the phone — no accounts, no server

## Install on Android

Host the repo with GitHub Pages (Settings → Pages → deploy from `main`), open the
URL in Chrome, then **⋮ → Add to Home screen**. It installs like an app, works
offline, and can show notifications.

## Develop

Edit `app.html`, then run `sh build.sh` to regenerate `index.html`.
