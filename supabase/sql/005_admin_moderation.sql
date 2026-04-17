-- 005_admin_moderation.sql
-- Admin roles, moderation, bans, and official content support.

create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  check (role in ('admin', 'moderator'))
);

create table if not exists public.user_bans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  issued_by uuid references auth.users(id) on delete set null,
  reason text,
  is_permanent boolean not null default false,
  banned_until timestamptz,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  check (is_permanent or banned_until is not null)
);

create index if not exists idx_user_bans_user_id on public.user_bans (user_id, created_at desc);
create index if not exists idx_user_bans_active on public.user_bans (user_id, revoked_at, banned_until);

alter table public.events add column if not exists is_official boolean not null default false;
alter table public.fields add column if not exists is_official boolean not null default false;

alter table public.admin_roles enable row level security;
alter table public.user_bans enable row level security;

create or replace function public.is_admin(admin_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.admin_roles ar
    where ar.user_id = admin_user_id
  );
$$;

-- Profiles: app needs authenticated users to browse public profiles.
drop policy if exists "Users can read own profile" on public.profiles;
create policy "Authenticated users can read profiles"
on public.profiles
for select
to authenticated
using (true);

-- admin_roles
drop policy if exists admin_roles_select_admin on public.admin_roles;
create policy admin_roles_select_admin
on public.admin_roles
for select
to authenticated
using (public.is_admin(auth.uid()));

-- user_bans
drop policy if exists user_bans_select_admin_or_self on public.user_bans;
create policy user_bans_select_admin_or_self
on public.user_bans
for select
to authenticated
using (public.is_admin(auth.uid()) or auth.uid() = user_id);

drop policy if exists user_bans_insert_admin on public.user_bans;
create policy user_bans_insert_admin
on public.user_bans
for insert
to authenticated
with check (public.is_admin(auth.uid()) and issued_by = auth.uid());

drop policy if exists user_bans_update_admin on public.user_bans;
create policy user_bans_update_admin
on public.user_bans
for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- Community moderation
drop policy if exists community_posts_delete_admin on public.community_posts;
create policy community_posts_delete_admin
on public.community_posts
for delete
to authenticated
using (public.is_admin(auth.uid()));

drop policy if exists community_posts_update_admin on public.community_posts;
create policy community_posts_update_admin
on public.community_posts
for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists community_comments_delete_admin on public.community_comments;
create policy community_comments_delete_admin
on public.community_comments
for delete
to authenticated
using (public.is_admin(auth.uid()));

drop policy if exists community_comments_update_admin on public.community_comments;
create policy community_comments_update_admin
on public.community_comments
for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- Events moderation and official events
drop policy if exists events_admin_insert on public.events;
create policy events_admin_insert
on public.events
for insert
to authenticated
with check (public.is_admin(auth.uid()));

drop policy if exists events_admin_update on public.events;
create policy events_admin_update
on public.events
for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists events_admin_delete on public.events;
create policy events_admin_delete
on public.events
for delete
to authenticated
using (public.is_admin(auth.uid()));

-- Fields admin management
drop policy if exists fields_admin_insert on public.fields;
create policy fields_admin_insert
on public.fields
for insert
to authenticated
with check (public.is_admin(auth.uid()));

drop policy if exists fields_admin_update on public.fields;
create policy fields_admin_update
on public.fields
for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists fields_admin_delete on public.fields;
create policy fields_admin_delete
on public.fields
for delete
to authenticated
using (public.is_admin(auth.uid()));
