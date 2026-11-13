-- Run once in Supabase (SQL Editor > New query > Run): ghosts + "only the first lap counts".

-- Each time comes with its lap (gzip + base64, see Game.encode_ghost). Rows are insert-only, so nobody can
-- replace someone else's ghost.
alter table public.lap_times add column ghost text check (ghost is null or char_length(ghost) <= 1000000);

-- A time without a ghost is refused: older versions of the game never send one, and they still try to upload
-- their old records (flying laps, faster than any first lap)
drop policy "anyone can add a time" on public.lap_times;
create policy "anyone can add a time with its ghost" on public.lap_times
  for insert to anon with check (ghost is not null);

-- same view, plus the row id (to download its ghost) and whether it has one; the ghost itself stays out of it
create or replace view public.leaderboard with (security_invoker = on) as
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

-- Last: deletes every time already on the leaderboard (flying laps). Old versions can no longer add any back.
truncate public.lap_times;
