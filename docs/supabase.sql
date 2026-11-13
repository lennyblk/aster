-- aster shared leaderboard. Run once in Supabase: SQL Editor > New query > paste > Run.
-- The game can only read times and add new ones (no update, no delete).

create table public.lap_times (
  id bigint generated always as identity primary key,
  player_id text not null check (char_length(player_id) between 8 and 64),
  player_name text not null check (char_length(player_name) between 1 and 16),
  map text not null check (char_length(map) between 1 and 32),
  time_ms integer not null check (time_ms between 5000 and 3600000),
  ghost text check (ghost is null or char_length(ghost) <= 1000000),   -- the lap, gzip + base64 (Game.encode_ghost)
  created_at timestamptz not null default now()
);

alter table public.lap_times enable row level security;

create policy "anyone can read times" on public.lap_times
  for select to anon using (true);

create policy "anyone can add a time with its ghost" on public.lap_times
  for insert to anon with check (ghost is not null);

grant select, insert on public.lap_times to anon;

-- best time of each player on each map, shown under the player's latest name
create view public.leaderboard with (security_invoker = on) as
  select distinct on (t.player_id, t.map) t.player_id, latest.player_name, t.map, t.time_ms, t.created_at,
    t.id, t.ghost is not null as has_ghost
  from public.lap_times t
  cross join lateral (
    select l.player_name from public.lap_times l
    where l.player_id = t.player_id
    order by l.created_at desc
    limit 1
  ) latest
  order by t.player_id, t.map, t.time_ms asc, t.created_at asc;

grant select on public.leaderboard to anon;
