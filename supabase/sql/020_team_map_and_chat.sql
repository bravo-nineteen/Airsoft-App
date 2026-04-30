-- Team tactical maps + live team messaging.

create table if not exists public.team_maps (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  title text not null,
  image_url text not null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.team_map_markers (
  id uuid primary key default gen_random_uuid(),
  map_id uuid not null references public.team_maps(id) on delete cascade,
  marker_type text not null default 'target',
  label text,
  x double precision not null,
  y double precision not null,
  color_hex text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (marker_type in ('respawn', 'target', 'objective', 'waypoint')),
  check (x >= 0 and x <= 1),
  check (y >= 0 and y <= 1)
);

create table if not exists public.team_map_routes (
  id uuid primary key default gen_random_uuid(),
  map_id uuid not null references public.team_maps(id) on delete cascade,
  label text,
  points jsonb not null default '[]'::jsonb,
  color_hex text,
  stroke_width double precision not null default 3,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(points) = 'array')
);

create table if not exists public.team_messages (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  sender_name text,
  sender_avatar_url text,
  body text not null,
  map_id uuid references public.team_maps(id) on delete set null,
  created_at timestamptz not null default now(),
  check (char_length(trim(body)) > 0)
);

create index if not exists idx_team_maps_team_id on public.team_maps(team_id, created_at desc);
create index if not exists idx_team_map_markers_map_id on public.team_map_markers(map_id, created_at asc);
create index if not exists idx_team_map_routes_map_id on public.team_map_routes(map_id, created_at asc);
create index if not exists idx_team_messages_team_id on public.team_messages(team_id, created_at asc);

alter table public.team_maps enable row level security;
alter table public.team_map_markers enable row level security;
alter table public.team_map_routes enable row level security;
alter table public.team_messages enable row level security;

-- Members with active membership can read/write team map and chat data.

drop policy if exists team_maps_member_select on public.team_maps;
create policy team_maps_member_select
  on public.team_maps
  for select
  to authenticated
  using (
    exists (
      select 1 from public.team_members tm
      where tm.team_id = team_maps.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_maps_member_insert on public.team_maps;
create policy team_maps_member_insert
  on public.team_maps
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and exists (
      select 1 from public.team_members tm
      where tm.team_id = team_maps.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

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
    )
  )
  with check (
    exists (
      select 1 from public.team_members tm
      where tm.team_id = team_maps.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_maps_member_delete on public.team_maps;
create policy team_maps_member_delete
  on public.team_maps
  for delete
  to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1 from public.teams t
      where t.id = team_maps.team_id and t.leader_id = auth.uid()
    )
  );

drop policy if exists team_map_markers_member_select on public.team_map_markers;
create policy team_map_markers_member_select
  on public.team_map_markers
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_markers.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_map_markers_member_insert on public.team_map_markers;
create policy team_map_markers_member_insert
  on public.team_map_markers
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_markers.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_map_markers_member_delete on public.team_map_markers;
create policy team_map_markers_member_delete
  on public.team_map_markers
  for delete
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
  );

drop policy if exists team_map_routes_member_select on public.team_map_routes;
create policy team_map_routes_member_select
  on public.team_map_routes
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_routes.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_map_routes_member_insert on public.team_map_routes;
create policy team_map_routes_member_insert
  on public.team_map_routes
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and exists (
      select 1
      from public.team_maps m
      join public.team_members tm on tm.team_id = m.team_id
      where m.id = team_map_routes.map_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_map_routes_member_delete on public.team_map_routes;
create policy team_map_routes_member_delete
  on public.team_map_routes
  for delete
  to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1
      from public.team_maps m
      join public.teams t on t.id = m.team_id
      where m.id = team_map_routes.map_id
        and t.leader_id = auth.uid()
    )
  );

drop policy if exists team_messages_member_select on public.team_messages;
create policy team_messages_member_select
  on public.team_messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.team_members tm
      where tm.team_id = team_messages.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_messages_member_insert on public.team_messages;
create policy team_messages_member_insert
  on public.team_messages
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.team_members tm
      where tm.team_id = team_messages.team_id
        and tm.user_id = auth.uid()
        and tm.status = 'active'
    )
  );

drop policy if exists team_messages_author_delete on public.team_messages;
create policy team_messages_author_delete
  on public.team_messages
  for delete
  to authenticated
  using (user_id = auth.uid());

drop trigger if exists trg_team_maps_set_updated_at on public.team_maps;
create trigger trg_team_maps_set_updated_at
before update on public.team_maps
for each row execute function public.set_updated_at();

-- Team map images bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'team-maps',
  'team-maps',
  true,
  15728640,
  array['image/jpeg','image/jpg','image/png','image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists team_maps_public_read on storage.objects;
create policy team_maps_public_read on storage.objects
  for select
  using (bucket_id = 'team-maps');

drop policy if exists team_maps_auth_insert on storage.objects;
create policy team_maps_auth_insert on storage.objects
  for insert
  with check (
    bucket_id = 'team-maps'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists team_maps_auth_update on storage.objects;
create policy team_maps_auth_update on storage.objects
  for update
  using (
    bucket_id = 'team-maps'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists team_maps_auth_delete on storage.objects;
create policy team_maps_auth_delete on storage.objects
  for delete
  using (
    bucket_id = 'team-maps'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
