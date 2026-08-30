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
- Optional reminder notification at a configurable time (fires while the app
  is open or installed)
- Buddies: tap **Add buddies** to get a 6-character code; two people who swap
  codes see each other's full streak (calendar, plank chart, badges), ranked
  by current streak, and can send cheers 📣 and nudges 👉 that pop up as
  toasts next time the other opens the app
- Data lives in `localStorage` on the phone — no sign-up. The buddy feature
  syncs your log to Supabase; everything else works fully offline

## Buddy sync backend (Supabase)

Project: `Streak Buddies` (`payvkfccgzwgsiflazuv`, eu-central-1). The embedded
key is the publishable anon key — safe to ship. Design:

- No Supabase Auth: registering returns a device-local `{uid, secret}` pair
  (kept in `localStorage`; the DB stores only a SHA-256 hash of the secret)
- Tables (`profiles`, `friendships`, `events`) have RLS enabled with **no
  policies** and all direct grants revoked — the anon key cannot touch them
- The only API surface is six `security definer` RPCs (`buddy_register`,
  `buddy_sync`, `buddy_add_friend`, `buddy_unfriend`, `buddy_send_event`,
  `buddy_delete`), each of which re-verifies the secret; friendship is
  mutual and instant when someone enters your code
- `buddy_sync` uploads your day log and returns friends' logs plus any
  pending cheer/nudge events (deleted on delivery)
- Erase-all in settings also calls `buddy_delete`, removing the server profile

Losing the phone's site data loses the buddy account (a fresh code must be
shared again) — the streak data itself can keep living on the device.

## Install on Android

Host the repo with GitHub Pages (Settings → Pages → deploy from `main`), open the
URL in Chrome, then **⋮ → Add to Home screen**. It installs like an app, works
offline, and can show notifications.

## Develop

Edit `app.html`, then run `sh build.sh` to regenerate `index.html`.
