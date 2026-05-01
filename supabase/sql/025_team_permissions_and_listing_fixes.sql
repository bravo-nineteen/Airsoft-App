-- Migration: team_permissions_and_listing_fixes
-- Reasserts user listing submissions, extends team metadata/roles, and
-- prepares tactical maps for richer icon editing.

alter table public.field_claim_requests
  add column if not exists official_id_image_url text;

alter table public.teams
  add column if not exists country text,
  add column if not exists prefecture text,
  add column if not exists city text,
  add column if not exists association text;

alter table public.team_members
  drop constraint if exists team_members_role_check;
alter table public.team_members
  add constraint team_members_role_check
  check (role in ('leader', 'squad_leader', 'member'));

alter table public.team_map_markers
  drop constraint if exists team_map_markers_marker_type_check;
alter table public.team_map_markers
  add column if not exists size_scale double precision not null default 1.0;
alter table public.team_map_markers
  add constraint team_map_markers_marker_type_check
  check (
    marker_type in (
      'respawn', 'target', 'objective', 'waypoint', 'label',
      'ammo', 'medic', 'bomb', 'terminal', 'extraction'
    )
  );

drop policy if exists "Authenticated users can submit fields" on public.fields;
create policy "Authenticated users can submit fields"
  on public.fields for insert to authenticated with check (true);

drop policy if exists "Authenticated users can submit shops" on public.shops;
create policy "Authenticated users can submit shops"
  on public.shops for insert to authenticated with check (true);

drop policy if exists team_maps_member_update on public.team_maps;
create policy team_maps_member_update
  on public.team_maps
  for update
  to authenticated
  using (
    exists (
      select 1 from public.team_members tm
      where tm.team_id = team_maps.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
        and tm.role in ('leader', 'squad_leader')
    )
  )
  with check (
    exists (
      select 1 from public.team_members tm
      where tm.team_id = team_maps.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
        and tm.role in ('leader', 'squad_leader')
    )
  );

drop policy if exists team_map_markers_member_update on public.team_map_markers;
create policy team_map_markers_member_update
  on public.team_map_markers
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_markers.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
        and tm.role in ('leader', 'squad_leader')
    )
  )
  with check (
    exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_markers.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
        and tm.role in ('leader', 'squad_leader')
    )
  );

drop policy if exists team_map_markers_member_delete on public.team_map_markers;
create policy team_map_markers_member_delete
  on public.team_map_markers
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_markers.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
        and tm.role in ('leader', 'squad_leader')
    )
  );

drop policy if exists team_map_routes_member_delete on public.team_map_routes;
create policy team_map_routes_member_delete
  on public.team_map_routes
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_routes.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
        and tm.role in ('leader', 'squad_leader')
    )
  );

drop policy if exists "Creator can delete zone" on public.team_map_zones;
create policy "Leaders and squad leaders can delete zone"
  on public.team_map_zones
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.team_maps tm
      join public.team_members mb on mb.team_id = tm.team_id
      where tm.id = team_map_zones.map_id
        and mb.user_id = auth.uid()
        and mb.status = 'active'
        and mb.role in ('leader', 'squad_leader')
    )
  );