# The Wiggle Squad 🫏🦝🐭🐮🐼

A cute exercise streak tracker — a five-animal cheer squad (Waffles the Donkey,
Bandit the Raccoon, Crumb the Rat, Clementine the Cow, and Bao the Panda)
celebrates every workout with confetti, wiggles, and milestone trophies.

## Files

- `app.html` — the whole app as a single self-contained fragment (source of truth,
  also what gets published as a Claude artifact for previews)
- `build.sh` — wraps `app.html` into `index.html` (full standalone page)
- `index.html` — generated; ready for GitHub Pages / any static host
- `manifest.webmanifest`, `sw.js` — PWA install + offline support when self-hosted

## Features

- One giant squishy "I moved today!" button with confetti, haptics, and pop sounds
- Streak counter, week strip, monthly calendar, and stats
- Milestone trophies at 3 / 7 / 14 / 21 / 30 / 50 / 75 / 100 days with a golden
  all-squad party animation
- "I actually exercised yesterday" rescue button so a forgotten log doesn't kill a streak
- Evening check-in: the coach of the day asks about the workout after 5pm, plus an
  optional browser notification at a configurable time (fires while the app is open
  or installed)
- Data lives in `localStorage` on the phone — no accounts, no server

## Install on Android

Host the repo with GitHub Pages (Settings → Pages → deploy from `main`), open the
URL in Chrome, then **⋮ → Add to Home screen**. It installs like an app, works
offline, and can show notifications.

## Develop

Edit `app.html`, then run `sh build.sh` to regenerate `index.html`.
