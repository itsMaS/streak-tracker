/* Sends the daily wake-up push to the phone subscribed in the app.
   Needs two repo secrets (Settings → Secrets and variables → Actions):
   - PUSH_SUBSCRIPTION: the JSON copied from the app (Settings → Angry raccoon → Copy)
   - VAPID_PRIVATE_KEY: the private half of the VAPID keypair whose public half
     is hardcoded in app.html */
const webpush = require("web-push");

const VAPID_PUBLIC_KEY = "BIE6jCotBRxxS0eknIHEsztxZHG7U_PCx0Sk0J2brx1mxRYBdb536dDVigeFTiF2OFTNBWj4Bd2YEhfgWwlBBoc";

let sub = null;
try { sub = JSON.parse(process.env.PUSH_SUBSCRIPTION || "null"); } catch (e) {}
if (!sub || !sub.endpoint) {
  console.log("PUSH_SUBSCRIPTION secret is missing or not valid JSON — nothing to send.");
  console.log("In the app: Settings → Angry raccoon → Copy, then paste into the secret.");
  process.exit(0);
}
if (!process.env.VAPID_PRIVATE_KEY) {
  console.error("VAPID_PRIVATE_KEY secret is missing.");
  process.exit(1);
}

webpush.setVapidDetails(
  "https://github.com/itsMaS/streak-tracker",
  VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

webpush
  .sendNotification(sub, JSON.stringify({ t: "nag-check" }), { TTL: 6 * 3600 })
  .then((res) => console.log("Push accepted by push service:", res.statusCode))
  .catch((err) => {
    if (err.statusCode === 404 || err.statusCode === 410) {
      console.error("Subscription expired or revoked (HTTP " + err.statusCode + ").");
      console.error("Re-enable Angry raccoon in the app and paste the fresh code into PUSH_SUBSCRIPTION.");
    } else {
      console.error("Push failed:", err.statusCode, err.body || err.message);
    }
    process.exit(1);
  });
