-- Reference copy of the schema applied to the "Streak Buddies" Supabase
-- project (payvkfccgzwgsiflazuv). Applied as migrations `buddy_schema` and
-- `buddy_revoke_authenticated`.
--
-- Identity model: each device registers and gets {uid, secret}; the secret is
-- stored hashed. All access goes through security-definer RPCs that verify the
-- secret. Tables have RLS enabled with NO policies, and direct grants are
-- revoked, so the publishable key alone can touch nothing directly.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  secret_hash text not null,
  name text not null,
  friend_code text not null unique,
  days jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.friendships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

create table public.events (
  from_id uuid not null references public.profiles(id) on delete cascade,
  to_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('cheer','nudge')),
  created_at timestamptz not null default now(),
  primary key (from_id, to_id, kind)
);

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.events enable row level security;

revoke all on public.profiles, public.friendships, public.events from anon, authenticated, public;

-- ---------- helpers ----------

create or replace function public._buddy_hash(p_secret text)
returns text
language sql immutable
set search_path = public, extensions
as $$
  select encode(extensions.digest(p_secret, 'sha256'), 'hex')
$$;

create or replace function public._buddy_auth(p_uid uuid, p_secret text)
returns void
language plpgsql stable
set search_path = public, extensions
as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = p_uid and secret_hash = public._buddy_hash(p_secret)
  ) then
    raise exception 'auth_failed' using errcode = '28000';
  end if;
end;
$$;

create or replace function public._buddy_gen_code()
returns text
language plpgsql volatile
set search_path = public, extensions
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where friend_code = code);
  end loop;
  return code;
end;
$$;

revoke all on function public._buddy_hash(text), public._buddy_auth(uuid, text), public._buddy_gen_code() from public, anon, authenticated;

-- ---------- public RPCs ----------

create or replace function public.buddy_register(p_name text)
returns jsonb
language plpgsql volatile security definer
set search_path = public, extensions
as $$
declare
  v_name text := trim(coalesce(p_name, ''));
  v_secret text := encode(extensions.gen_random_bytes(24), 'hex');
  v_code text := public._buddy_gen_code();
  v_id uuid;
begin
  if v_name = '' or char_length(v_name) > 24 then
    raise exception 'bad_name';
  end if;
  insert into public.profiles (secret_hash, name, friend_code)
  values (public._buddy_hash(v_secret), v_name, v_code)
  returning id into v_id;
  return jsonb_build_object('uid', v_id, 'secret', v_secret, 'code', v_code, 'name', v_name);
end;
$$;

create or replace function public.buddy_sync(p_uid uuid, p_secret text, p_days jsonb, p_name text default null)
returns jsonb
language plpgsql volatile security definer
set search_path = public, extensions
as $$
declare
  v_friends jsonb;
  v_events jsonb;
  v_name text := trim(coalesce(p_name, ''));
begin
  perform public._buddy_auth(p_uid, p_secret);
  if jsonb_typeof(p_days) is distinct from 'object' then
    raise exception 'bad_days';
  end if;
  if pg_column_size(p_days) > 262144 then
    raise exception 'days_too_big';
  end if;
  update public.profiles
  set days = p_days,
      name = case when v_name <> '' and char_length(v_name) <= 24 then v_name else name end,
      updated_at = now()
  where id = p_uid;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', pr.id, 'name', pr.name, 'days', pr.days, 'updated_at', pr.updated_at)
           order by pr.name), '[]'::jsonb)
  into v_friends
  from public.friendships f
  join public.profiles pr on pr.id = f.friend_id
  where f.user_id = p_uid;

  with delivered as (
    delete from public.events where to_id = p_uid
    returning from_id, kind, created_at
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'from', d.from_id, 'kind', d.kind, 'at', d.created_at)
           order by d.created_at), '[]'::jsonb)
  into v_events
  from delivered d;

  return jsonb_build_object('friends', v_friends, 'events', v_events);
end;
$$;

create or replace function public.buddy_add_friend(p_uid uuid, p_secret text, p_code text)
returns jsonb
language plpgsql volatile security definer
set search_path = public, extensions
as $$
declare
  v_friend public.profiles%rowtype;
  v_count int;
begin
  perform public._buddy_auth(p_uid, p_secret);
  select * into v_friend from public.profiles
  where friend_code = upper(trim(coalesce(p_code, '')));
  if not found then
    raise exception 'code_not_found';
  end if;
  if v_friend.id = p_uid then
    raise exception 'cannot_add_self';
  end if;
  select count(*) into v_count from public.friendships where user_id = p_uid;
  if v_count >= 50 then
    raise exception 'too_many_friends';
  end if;
  insert into public.friendships (user_id, friend_id)
  values (p_uid, v_friend.id), (v_friend.id, p_uid)
  on conflict do nothing;
  return jsonb_build_object('id', v_friend.id, 'name', v_friend.name,
                            'days', v_friend.days, 'updated_at', v_friend.updated_at);
end;
$$;

create or replace function public.buddy_unfriend(p_uid uuid, p_secret text, p_fid uuid)
returns void
language plpgsql volatile security definer
set search_path = public, extensions
as $$
begin
  perform public._buddy_auth(p_uid, p_secret);
  delete from public.friendships
  where (user_id = p_uid and friend_id = p_fid) or (user_id = p_fid and friend_id = p_uid);
  delete from public.events
  where (from_id = p_uid and to_id = p_fid) or (from_id = p_fid and to_id = p_uid);
end;
$$;

create or replace function public.buddy_send_event(p_uid uuid, p_secret text, p_to uuid, p_kind text)
returns void
language plpgsql volatile security definer
set search_path = public, extensions
as $$
begin
  perform public._buddy_auth(p_uid, p_secret);
  if p_kind not in ('cheer', 'nudge') then
    raise exception 'bad_kind';
  end if;
  if not exists (select 1 from public.friendships where user_id = p_uid and friend_id = p_to) then
    raise exception 'not_friends';
  end if;
  insert into public.events (from_id, to_id, kind)
  values (p_uid, p_to, p_kind)
  on conflict (from_id, to_id, kind) do update set created_at = now();
end;
$$;

create or replace function public.buddy_delete(p_uid uuid, p_secret text)
returns void
language plpgsql volatile security definer
set search_path = public, extensions
as $$
begin
  perform public._buddy_auth(p_uid, p_secret);
  delete from public.profiles where id = p_uid;
end;
$$;

revoke all on function
  public.buddy_register(text),
  public.buddy_sync(uuid, text, jsonb, text),
  public.buddy_add_friend(uuid, text, text),
  public.buddy_unfriend(uuid, text, uuid),
  public.buddy_send_event(uuid, text, uuid, text),
  public.buddy_delete(uuid, text)
from public, authenticated;

grant execute on function
  public.buddy_register(text),
  public.buddy_sync(uuid, text, jsonb, text),
  public.buddy_add_friend(uuid, text, text),
  public.buddy_unfriend(uuid, text, uuid),
  public.buddy_send_event(uuid, text, uuid, text),
  public.buddy_delete(uuid, text)
to anon;
