-- Migration: team_map_marker_updates
-- Allows creators and team leaders to update marker position/appearance.

drop policy if exists team_map_markers_member_update on public.team_map_markers;
create policy team_map_markers_member_update
  on public.team_map_markers
  for update
  to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1
      from public.team_maps m
      join public.teams t on t.id = m.team_id
      where m.id = team_map_markers.map_id
        and t.leader_id = auth.uid()
    )
  )
  with check (
    created_by = auth.uid()
    or exists (
      select 1
      from public.team_maps m
      join public.teams t on t.id = m.team_id
      where m.id = team_map_markers.map_id
        and t.leader_id = auth.uid()
    )
  );