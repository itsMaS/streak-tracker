# Claude notes

- **Always push directly to `main`** (user preference, stated 2026-08-30).
  GitHub Pages deploys the live app from `main`, so work isn't live until
  it lands there. No PRs needed unless explicitly asked.
- **The `staging` branch is abandoned — do not use it (2026-09-02).** The
  zoo/sprite rework there was scrapped; the user is redoing that work on a
  different branch. Never build on, merge, or push to `staging`.
- **No emoji anywhere in the app** (user preference, stated 2026-09-02):
  new features must not add emoji characters to `app.html` or `sw.js`;
  use drawn SVG instead. (The existing emoji predate the rule.)
- `app.html` is the source of truth; run `sh build.sh` after editing it to
  regenerate `index.html`, and commit both.
- Bump the `CACHE` version in `sw.js` whenever shipped files change, or
  installed PWAs keep serving the old build.
- Buddy/social features use the Supabase project `Streak Buddies`
  (`payvkfccgzwgsiflazuv`, eu-central-1); the schema lives in
  `supabase/schema.sql` (reference copy — apply changes as migrations via
  the Supabase connector). Tables are RLS deny-all; the only API surface is
  the `buddy_*` and `push_*` security-definer RPCs.
- Angry raccoon push: subscriptions live in `push_subscriptions`; a pg_cron
  job invokes the `send-nags` edge function (source in
  `supabase/functions/send-nags/`) every 10 min. The VAPID private key is in
  the `push_config` table (service-role only) — NEVER in this public repo;
  the public key is hardcoded in `app.html` and the edge function. Server
  setup/verification steps: `supabase/DEPLOY_NAGS.md`.
