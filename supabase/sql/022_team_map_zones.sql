-- Migration: team_map_zones
-- Stores drawn zone polygons on tactical maps.

create table if not exists public.team_map_zones (
  id          uuid primary key default gen_random_uuid(),
  map_id      uuid not null references public.team_maps(id) on delete cascade,
  points      jsonb not null default '[]',
  label       text,
  color_hex   text,
  created_by  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now()
);

alter table public.team_map_zones enable row level security;

-- Team members can read zones on maps they belong to (via team_maps → teams → team_members)
create policy "Team members can view zones" on public.team_map_zones
  for select to authenticated
  using (
    exists (
      select 1 from public.team_maps tm
      join public.team_members mb on mb.team_id = tm.team_id
      where tm.id = team_map_zones.map_id
        and mb.user_id = auth.uid()
        and mb.status = 'active'
    )
  );

-- Team members can insert zones
create policy "Team members can add zones" on public.team_map_zones
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.team_maps tm
      join public.team_members mb on mb.team_id = tm.team_id
      where tm.id = map_id
        and mb.user_id = auth.uid()
        and mb.status = 'active'
    )
  );

-- Only creator can delete their own zones
create policy "Creator can delete zone" on public.team_map_zones
  for delete to authenticated
  using (created_by = auth.uid());

create index if not exists team_map_zones_map_id_idx on public.team_map_zones(map_id);
