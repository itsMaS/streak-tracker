# Deploy brief: angry raccoon push (Supabase side)

For a Claude session with the Supabase connector attached. The repo side is
already done and on `main`; this brief covers only the server setup on the
`Streak Buddies` project (`payvkfccgzwgsiflazuv`, eu-central-1). Delete this
file once everything below is verified working.

## Status (2026-08-30)

- Step 1 done — migration `push_nags` applied (tables + RPCs live).
- Step 2 **pending** — waiting on Martynas for the VAPID private key; until
  it's inserted the function returns 500 "vapid_private_key missing".
- Step 3 done — `send-nags` deployed (v1, JWT verification on).
- Step 4 done — `pg_cron` + `pg_net` enabled, job `send-nags` scheduled
  every 10 minutes with the publishable key.
- Step 5 partly done — manual invoke via `net.http_post` returned the
  expected 500 naming `push_config`. Remaining once the key is in: invoke
  again expecting `{"total":0,...}` 200, then the phone-subscription test.

## Context

The app lets a phone subscribe to web push (Settings → Angry raccoon). The
subscription is stored via the `push_register` RPC together with the user's
reminder time and IANA timezone. A cron-invoked edge function
(`supabase/functions/send-nags/index.ts`) must send each due subscription one
wake-up push per local day; the phone's service worker then shows an angry
raccoon if nothing is logged that day. Full schema for the new tables/RPCs is
at the bottom of `supabase/schema.sql` (section "angry raccoon push").

## Steps

1. **Migration `push_nags`** — apply the "angry raccoon push" section of
   `supabase/schema.sql` verbatim (tables `push_config`, `push_subscriptions`;
   RPCs `push_register`, `push_unregister`; RLS deny-all + grants).

2. **VAPID private key** — ask Martynas for the value (generated in the chat
   that built this feature; also needed: nothing else). Then:
   ```sql
   insert into public.push_config (key, value)
   values ('vapid_private_key', '<PASTE-KEY-HERE>')
   on conflict (key) do update set value = excluded.value;
   ```
   Never commit this value to the repo (it's public). The matching public key
   is already hardcoded in `app.html` (`VAPID_PUB`) and in the edge function
   (`VAPID_PUBLIC_JWK`) — do not regenerate the pair or existing phone
   subscriptions die.

3. **Deploy the edge function** — deploy `supabase/functions/send-nags/index.ts`
   as `send-nags` (default JWT verification on is fine; the cron call below
   sends the anon key). If the `jsr:@negrel/webpush` import or its API
   (`importVapidKeys`, `ApplicationServer.new`, `subscribe`,
   `pushTextMessage`) doesn't match at the pinned version, check the current
   API on jsr.io/@negrel/webpush and adapt — keep the JWK-based key loading.

4. **Cron every 10 minutes** — enable `pg_cron` + `pg_net`, then:
   ```sql
   select cron.schedule(
     'send-nags', '*/10 * * * *',
     $$
     select net.http_post(
       url := 'https://payvkfccgzwgsiflazuv.supabase.co/functions/v1/send-nags',
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'Authorization', 'Bearer ' || '<ANON-KEY>'
       ),
       body := '{}'::jsonb
     )
     $$
   );
   ```
   (Substitute the project's anon/publishable key; it's public — same one as
   `SB_KEY` in `app.html`.)

5. **Verify** —
   - Invoke `send-nags` once manually: expect
     `{"total":0,"sent":0,"dropped":0,"failed":0}` while no one is subscribed,
     HTTP 200 (or 500 naming `push_config` if step 2 was skipped).
   - Have Martynas flip Settings → Angry raccoon on his phone, confirm a row
     appears in `push_subscriptions` with his tz and nag time.
   - Temporarily set that row's `nag_time` to a minute or two ago
     (`update public.push_subscriptions set nag_time = to_char(now() at time zone tz, 'HH24:MI'), last_nag_date = null;`)
     then invoke the function: expect `sent: 1` and a raccoon on the phone
     (calm "streak safe" version if he already logged today).
   - Check function logs for errors; 404/410 rows are auto-deleted by design.

## Notes

- `last_nag_date` is the user's *local* date string; the function is
  idempotent per local day, so extra invocations are harmless.
- The 500-row cap in `push_register` is a spam guard, not a product limit.
- The old GitHub Actions sender (`angry-push.yml` + `PUSH_SUBSCRIPTION` /
  `VAPID_PRIVATE_KEY` repo secrets) was removed from the repo; the repo
  secrets on GitHub can be deleted if they were ever created.
