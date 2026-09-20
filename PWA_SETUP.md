# Brief: browser + installable app setup (PWA on GitHub Pages)

For an agent setting up the same arrangement Streak Buddies uses: one static
page that opens in any browser at a URL, and installs to an Android/iOS home
screen as a standalone app with an icon, offline start and notifications. No
build tooling, no server, no app store.

This is the working recipe plus the four things that broke the first time, so
they don't have to be rediscovered. Everything here is live in this repo -
read `build.sh`, `manifest.webmanifest`, `sw.js` and the last ~30 lines of
`app.html` alongside it.

## What "working" means

Three separate outcomes, each with its own failure mode:

1. **Web**: the URL loads in a desktop or mobile browser tab.
2. **Installable**: Chrome on Android offers *"Install app"* (not *"Add to
   Home screen"*, which is the shortcut-only fallback and the tell that the
   PWA setup is wrong), the installed app opens without browser chrome, and
   has the real icon. iOS installs via Share -> Add to Home Screen.
3. **Offline + background**: it opens with no signal, and the service worker
   can show notifications while the app is closed.

## File layout

| File | Role |
| --- | --- |
| `app.html` | the whole app as a self-contained fragment - source of truth, also pasteable as a Claude artifact for previews |
| `build.sh` | wraps the fragment into `index.html` with a correct `<head>` |
| `index.html` | generated, committed, served |
| `manifest.webmanifest` | install metadata (name, icons, colors, scope) |
| `sw.js` | service worker: offline cache + push handling |
| `icons/` | real PNGs: 192, 512, maskable 512 |

`app.html` being a fragment is what makes it double as an artifact; the head
is why `build.sh` exists at all.

## Setup

1. **Host over HTTPS on a stable origin.** GitHub Pages: Settings -> Pages ->
   deploy from branch `main`, root. Gives `https://<user>.github.io/<repo>/`.
   HTTPS is mandatory - service workers and push refuse to run on plain HTTP
   (localhost is the only exception, useful for testing).

2. **Keep every path relative.** The app lives under a subpath (`/<repo>/`),
   so absolute paths (`/sw.js`, `/icons/...`) resolve to the domain root and
   404. Use `"start_url": "."`, `"scope": "./"`, `href="manifest.webmanifest"`,
   `register("sw.js")`. This is also what makes the app work unchanged from a
   custom domain or a local `python3 -m http.server`.

3. **Write the manifest** with `id`, `name`, `short_name`, `start_url`,
   `scope`, `display: "standalone"`, `background_color`, `theme_color`, and
   PNG icons at 192 and 512 plus a maskable 512. See below on icons.

4. **Emit the PWA tags into `<head>` from the build script**, not the
   fragment: `charset`, viewport with `viewport-fit=cover`, `theme-color`,
   `<title>`, `<link rel="manifest">`, `<link rel="icon">`,
   `<link rel="apple-touch-icon">`. `build.sh` also `sed`s the fragment's own
   manifest link and title out of the body so they aren't duplicated.

5. **Register the service worker** at the end of the app script:
   `if("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(()=>{});`
   The worker must sit at the repo root - a worker's scope cannot rise above
   its own directory, so `js/sw.js` could never control `/`.

6. **Service worker**: precache `["./", "index.html", "manifest.webmanifest",
   <icons>]` on install, `skipWaiting()` + `clients.claim()`, delete old
   caches on activate, and serve fetches network-first with a cache fallback.
   Network-first keeps browser visitors on fresh code; the cache only steps in
   when the network fails.

7. **In-app install button** (optional but worth it): capture
   `beforeinstallprompt`, `preventDefault()` it, stash the event, show a
   header button, and call `.prompt()` on click. Hide the button when
   `matchMedia("(display-mode: standalone)").matches || navigator.standalone`
   - already installed. iOS never fires the event, so detect it by user agent
   and show the Share -> Add to Home Screen instructions instead.

8. **Build and commit both files**: `sh build.sh`, commit `app.html` and
   `index.html` together. Pages serves what's committed.

## The four things that broke it

1. **Manifest linked from `<body>`.** Chrome silently ignores it. The site
   looked fine, passed no error anywhere, and offered only a bookmark-style
   shortcut with a screenshot icon. Fix: manifest link in `<head>`, which is
   the entire reason `build.sh` builds a head instead of `cat`ing the
   fragment into a bare page. (Commit `2bdee53`.)

2. **SVG data-URI icon in the manifest.** Chrome on Android requires real
   raster icons - 192 and 512 PNG - to offer a full install; an SVG data URI
   again yields shortcut-only. Add a third `purpose: "maskable"` 512 so
   Android doesn't letterbox the icon inside its adaptive shape.
   (Commit `4bbb2c9`.)

3. **Stale installed app after a deploy.** An installed PWA keeps serving the
   precached build until the cache name changes. Bump the `CACHE` constant in
   `sw.js` on every change to shipped files - this is the single easiest step
   to forget, and it makes a deploy look like it silently failed on the one
   device that matters.

4. **`localStorage` is invisible to the service worker.** Any state the
   worker needs while the app is closed (here: today's log, to decide which
   notification to show) has to be mirrored into IndexedDB by the page on
   every save, and read from there in the `push` handler.

## Notifications, briefly

Permission must be requested from a real user gesture (a settings toggle),
never on load. iOS only allows web push for an app already added to the home
screen, so gate the toggle and say so in the copy. The rest of this app's
push path (VAPID keys, Supabase cron, edge function) is out of scope here -
see `supabase/DEPLOY_NAGS.md`.

## Verification

Desktop Chrome, DevTools -> Application:

- *Manifest*: all fields parsed, icons render, no warnings.
- *Service Workers*: activated and running.
- Offline checkbox on, reload: the app still opens.
- Lighthouse -> Installability: an explicit pass or a named reason.

Android phone (the real test - desktop passing is not sufficient):

- Chrome menu reads **Install app**, not Add to Home screen.
- Installed icon is the real icon, not a screenshot thumbnail.
- Launching from the home screen shows no URL bar.
- Airplane mode, launch: it opens.
- After a deploy with a bumped cache version, the installed app shows the
  change on second launch.

Remote-debug the phone over `chrome://inspect` when something disagrees with
the desktop result.

## Rules for whoever maintains it

- Edit `app.html`, run `sh build.sh`, commit both files.
- Bump `CACHE` in `sw.js` whenever any shipped file changes.
- Keep new paths relative.
- Don't move `sw.js` out of the root.
