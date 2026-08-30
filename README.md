# The Midnight Menagerie 🫏🦝🐭🐮🐼

A very dark horror exercise streak tracker — five ominous beasts (Hollow the
Donkey, Grimm the Raccoon, Vermin the Rat, The Heifer, and Mourn the Panda)
demand a daily offering of exercise. Feeding the streak brings ash-and-bat
bursts, tolling bells, and milestone rites on the relic shelf.

## Files

- `app.html` — the whole app as a single self-contained fragment (source of truth,
  also what gets published as a Claude artifact for previews)
- `build.sh` — wraps `app.html` into `index.html` (full standalone page)
- `index.html` — generated; ready for GitHub Pages / any static host
- `manifest.webmanifest`, `sw.js` — PWA install + offline support when self-hosted

## Features

- One giant "Feed the Streak 🩸" button with ash/bat/skull bursts, haptics, and
  low tolling sounds
- Streak counter ("nights kept"), week strip, monthly calendar, and stats
- Milestone rites at 3 / 7 / 14 / 21 / 30 / 50 / 75 / 100 nights with a blood-moon
  all-beast procession animation
- "I performed yesterday's ritual" rescue button so a forgotten log doesn't kill a streak
- Evening summons: the keeper of the night asks about the workout after 5pm, plus an
  optional browser notification at a configurable time (fires while the app is open
  or installed)
- Data lives in `localStorage` on the phone — no accounts, no server

## Install on Android

Host the repo with GitHub Pages (Settings → Pages → deploy from `main`), open the
URL in Chrome, then **⋮ → Add to Home screen**. It installs like an app, works
offline, and can show notifications.

## Develop

Edit `app.html`, then run `sh build.sh` to regenerate `index.html`.
