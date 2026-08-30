/* Minimal offline cache so the installed PWA opens instantly, even without signal. */
const CACHE = "streak-buddies-v6";
const ASSETS = ["./", "index.html", "manifest.webmanifest", "icons/icon-192.png", "icons/icon-512.png", "icons/maskable-512.png", "icons/angry.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    fetch(e.request)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});

/* ---------- angry raccoon push ----------
   A GitHub Actions cron sends a daily push (see .github/workflows/angry-push.yml).
   The push wakes this worker even when the app is closed and the phone is locked.
   The app mirrors its day log into IndexedDB ("streak-push"/"kv"/"days"), so the
   decision — angry or calm — is made here on the phone, not on the server. */

function readDays() {
  return new Promise((resolve) => {
    try {
      const req = indexedDB.open("streak-push", 1);
      req.onupgradeneeded = () => { req.result.createObjectStore("kv"); };
      req.onerror = () => resolve(null);
      req.onsuccess = () => {
        const db = req.result;
        try {
          const get = db.transaction("kv").objectStore("kv").get("days");
          get.onsuccess = () => { db.close(); resolve(get.result || null); };
          get.onerror = () => { db.close(); resolve(null); };
        } catch (e) { db.close(); resolve(null); }
      };
    } catch (e) { resolve(null); }
  });
}

self.addEventListener("push", (e) => {
  e.waitUntil((async () => {
    const days = await readDays();
    const d = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    const today = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    /* A workout OR a migraine day counts as handled — the streak is safe. */
    const done = !!(days && days[today]);
    if (done) {
      await self.registration.showNotification("Streak safe 🎉", {
        body: "Today is logged. The raccoon is at peace.",
        icon: "icons/icon-192.png",
        tag: "angry-raccoon",
        silent: true
      });
    } else {
      await self.registration.showNotification("THE RACCOON IS ANGRY 😡", {
        body: "Nothing logged today. Do your workout before midnight!",
        icon: "icons/icon-192.png",
        image: "icons/angry.png",
        tag: "angry-raccoon",
        requireInteraction: true,
        vibrate: [200, 100, 200, 100, 400]
      });
    }
  })());
});

self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  e.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
      for (const c of list) if ("focus" in c) return c.focus();
      return self.clients.openWindow("./");
    })
  );
});
