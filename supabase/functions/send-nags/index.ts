// Angry raccoon dispatcher. Invoked by pg_cron every 10 minutes (see
// supabase/DEPLOY_NAGS.md). Sends a wake-up web push to every subscription
// whose *local* time has passed its nag time and that wasn't nagged yet
// today in its own timezone. The payload carries no personal data — the
// service worker on the phone decides angry vs calm from its local day log.
//
// VAPID: the public key below must match VAPID_PUB in app.html; the private
// key is read from the push_config table (key 'vapid_private_key'), which is
// RLS-locked to the service role.
import * as webpush from "jsr:@negrel/webpush@0.5.0";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const VAPID_PUBLIC_JWK = {
  kty: "EC",
  crv: "P-256",
  x: "gTqMKi0FHHFLR6ScgcSzO3FkcbtT88LHRKTQnZuvHWY",
  y: "xRYBdb536dDVigeFTiF2OFTNBWj4Bd2YEhfgWwlBBoc",
};

async function sb(path: string, init: RequestInit = {}): Promise<Response> {
  const r = await fetch(`${SB_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  if (!r.ok) throw new Error(`${path}: ${r.status} ${await r.text()}`);
  return r;
}

// "now" in a given IANA timezone, as {date: "YYYY-MM-DD", hm: "HH:MM"}.
function localNow(tz: string): { date: string; hm: string } | null {
  try {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: tz,
      year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", minute: "2-digit", hourCycle: "h23",
    }).formatToParts(new Date());
    const g = (t: string) => parts.find((p) => p.type === t)?.value ?? "00";
    return {
      date: `${g("year")}-${g("month")}-${g("day")}`,
      hm: `${g("hour")}:${g("minute")}`,
    };
  } catch {
    return null; // unknown timezone string
  }
}

Deno.serve(async () => {
  const cfg = await (await sb("push_config?key=eq.vapid_private_key&select=value")).json();
  if (!cfg.length) {
    return new Response("vapid_private_key missing from push_config", { status: 500 });
  }

  const vapidKeys = await webpush.importVapidKeys(
    {
      publicKey: VAPID_PUBLIC_JWK,
      privateKey: { ...VAPID_PUBLIC_JWK, d: cfg[0].value },
    },
    { extractable: false },
  );
  const appServer = await webpush.ApplicationServer.new({
    contactInformation: "https://github.com/itsMaS/streak-tracker",
    vapidKeys,
  });

  const subs = await (await sb("push_subscriptions?select=*")).json();
  let sent = 0, dropped = 0, failed = 0;

  for (const row of subs) {
    const now = localNow(row.tz);
    if (!now) continue;
    // "HH:MM" strings compare correctly as text; catch-up semantics mean any
    // cron tick after nag_time sends, but only once per local day.
    if (now.hm < row.nag_time || row.last_nag_date === now.date) continue;

    const byEndpoint = `push_subscriptions?endpoint=eq.${encodeURIComponent(row.endpoint)}`;
    try {
      const subscriber = appServer.subscribe(row.subscription);
      await subscriber.pushTextMessage(JSON.stringify({ t: "nag-check" }), {});
      await sb(byEndpoint, {
        method: "PATCH",
        body: JSON.stringify({ last_nag_date: now.date, updated_at: new Date().toISOString() }),
      });
      sent++;
    } catch (err) {
      // 404/410 from the push service = subscription is gone; forget it.
      const status = (err as { response?: { status?: number } })?.response?.status;
      if (status === 404 || status === 410) {
        await sb(byEndpoint, { method: "DELETE" });
        dropped++;
      } else {
        failed++;
        console.error("push failed:", String(row.endpoint).slice(0, 60), err);
      }
    }
  }

  return Response.json({ total: subs.length, sent, dropped, failed });
});
