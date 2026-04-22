create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references auth.users(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  author_name text not null default 'Unknown',
  author_avatar_url text,
  title text not null default '',
  body_text text not null default '',
  plain_text text not null default '',
  body_delta_json jsonb,
  image_url text,
  image_urls text[] not null default '{}',
  category text,
  language text default 'english',
  language_code text default 'en',
  visibility text not null default 'public',
  post_context text not null default 'community',
  target_user_id uuid references auth.users(id) on delete set null,
  is_bulletin boolean not null default false,
  is_pinned boolean not null default false,
  is_locked boolean not null default false,
  is_deleted boolean not null default false,
  comment_count integer not null default 0,
  like_count integer not null default 0,
  view_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_community_posts_created_at
  on public.community_posts (created_at desc);
create index if not exists idx_community_posts_author_id
  on public.community_posts (author_id);
create index if not exists idx_community_posts_user_id
  on public.community_posts (user_id);
create index if not exists idx_community_posts_target_user_id
  on public.community_posts (target_user_id);
create index if not exists idx_community_posts_context
  on public.community_posts (post_context);
create index if not exists idx_community_posts_category
  on public.community_posts (category);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  parent_comment_id uuid references public.community_comments(id) on delete cascade,
  author_id uuid references auth.users(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  author_name text not null default 'Unknown',
  author_avatar_url text,
  message text not null default '',
  body text not null default '',
  language text default 'english',
  is_deleted boolean not null default false,
  is_locked boolean not null default false,
  like_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_community_comments_post_id
  on public.community_comments (post_id);
create index if not exists idx_community_comments_parent_comment_id
  on public.community_comments (parent_comment_id);
create index if not exists idx_community_comments_author_id
  on public.community_comments (author_id);
create index if not exists idx_community_comments_user_id
  on public.community_comments (user_id);
create index if not exists idx_community_comments_created_at
  on public.community_comments (created_at desc);

create table if not exists public.community_post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create index if not exists idx_community_post_likes_post_id
  on public.community_post_likes (post_id);
create index if not exists idx_community_post_likes_user_id
  on public.community_post_likes (user_id);

create table if not exists public.community_comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.community_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

create index if not exists idx_community_comment_likes_comment_id
  on public.community_comment_likes (comment_id);
create index if not exists idx_community_comment_likes_user_id
  on public.community_comment_likes (user_id);

create table if not exists public.user_contacts (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id),
  check (status in ('pending', 'accepted')),
  unique (requester_id, addressee_id)
);

create index if not exists idx_user_contacts_requester_id
  on public.user_contacts (requester_id);
create index if not exists idx_user_contacts_addressee_id
  on public.user_contacts (addressee_id);
create index if not exists idx_user_contacts_status
  on public.user_contacts (status);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.direct_messages add column if not exists image_url text;
alter table public.direct_messages add column if not exists expires_at timestamptz;
alter table public.direct_messages add column if not exists unsent_at timestamptz;

create index if not exists idx_direct_messages_sender_id
  on public.direct_messages (sender_id, created_at desc);
create index if not exists idx_direct_messages_recipient_id
  on public.direct_messages (recipient_id, created_at desc);
create index if not exists idx_direct_messages_unread
  on public.direct_messages (recipient_id, read_at)
  where read_at is null;
create index if not exists idx_direct_messages_expires_at
  on public.direct_messages (expires_at)
  where expires_at is not null;

drop view if exists public.direct_message_threads cascade;
create view public.direct_message_threads as
with base as (
  select
    dm.sender_id,
    dm.recipient_id,
    dm.body,
    dm.created_at,
    dm.read_at,
    case when dm.sender_id = auth.uid() then dm.recipient_id else dm.sender_id end as other_user_id
  from public.direct_messages dm
  where dm.sender_id = auth.uid() or dm.recipient_id = auth.uid()
), ranked as (
  select
    b.*,
    row_number() over (partition by b.other_user_id order by b.created_at desc) as rn
  from base b
)
select
  auth.uid() as current_user_id,
  r.other_user_id,
  r.body as last_message_body,
  r.created_at as last_message_at,
  (
    select count(*)::int
    from base bu
    where bu.other_user_id = r.other_user_id
      and bu.recipient_id = auth.uid()
      and bu.read_at is null
  ) as unread_count
from ranked r
where r.rn = 1;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  type text not null,
  entity_id uuid,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_id_created
  on public.notifications (user_id, created_at desc);
create index if not exists idx_notifications_user_id_unread
  on public.notifications (user_id, is_read, created_at desc);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid references auth.users(id) on delete set null,
  title text not null,
  description text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  location text,
  prefecture text,
  event_type text,
  language text,
  skill_level text,
  organizer_name text,
  contact_info text,
  notes text,
  price_yen integer,
  max_players integer,
  image_url text,
  book_tickets_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);

alter table public.events add column if not exists pinned_until timestamptz;
alter table public.events add column if not exists image_uploaded_at timestamptz;
alter table public.events add column if not exists book_tickets_url text;

update public.events
set image_uploaded_at = coalesce(updated_at, created_at, now())
where image_url is not null
  and image_uploaded_at is null;

create or replace function public.set_events_image_uploaded_at()
returns trigger
language plpgsql
as $$
begin
  if new.image_url is null then
    new.image_uploaded_at := null;
  elsif tg_op = 'INSERT'
     or old.image_url is distinct from new.image_url
     or new.image_uploaded_at is null then
    new.image_uploaded_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_events_set_image_uploaded_at on public.events;
create trigger trg_events_set_image_uploaded_at
before insert or update on public.events
for each row execute function public.set_events_image_uploaded_at();

create or replace function public.cleanup_expired_event_images()
returns integer
language plpgsql
as $$
declare
  affected_count integer := 0;
begin
  update public.events
  set image_url = null,
      image_uploaded_at = null
  where image_url is not null
    and coalesce(image_uploaded_at, updated_at, created_at) <= now() - interval '6 months';

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

do $$
begin
  begin
    execute 'create extension if not exists pg_cron';
  exception
    when others then
      null;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'cleanup-expired-event-images';

    perform cron.schedule(
      'cleanup-expired-event-images',
      '0 3 * * *',
      'select public.cleanup_expired_event_images();'
    );
  end if;
end;
$$;

create index if not exists idx_events_starts_at on public.events (starts_at asc);
create index if not exists idx_events_host_user_id on public.events (host_user_id);

create table if not exists public.event_attendees (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'attending',
  confirmed_by_host boolean not null default false,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('attending', 'attended', 'cancelled', 'no_show')),
  unique (event_id, user_id)
);

create table if not exists public.event_comments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  parent_comment_id uuid references public.event_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_event_comments_event_id
  on public.event_comments (event_id, created_at asc);
create index if not exists idx_event_comments_parent_comment_id
  on public.event_comments (parent_comment_id);
create index if not exists idx_event_comments_user_id
  on public.event_comments (user_id);

alter table public.event_attendees add column if not exists confirmed_by_host boolean not null default false;
alter table public.event_attendees add column if not exists confirmed_at timestamptz;
alter table public.community_posts add column if not exists updated_at timestamptz not null default now();
alter table public.community_comments add column if not exists updated_at timestamptz not null default now();
alter table public.user_contacts add column if not exists updated_at timestamptz not null default now();
alter table public.notifications add column if not exists updated_at timestamptz not null default now();
alter table public.events add column if not exists updated_at timestamptz not null default now();
alter table public.event_attendees add column if not exists updated_at timestamptz not null default now();
alter table public.fields add column if not exists feature_list text;
alter table public.fields add column if not exists pros_list text;
alter table public.fields add column if not exists cons_list text;
alter table public.profiles add column if not exists loadout_cards jsonb not null default '[]'::jsonb;

create table if not exists public.field_reviews (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review_text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (field_id, user_id)
);

create index if not exists idx_event_attendees_event_id on public.event_attendees (event_id);
create index if not exists idx_event_attendees_user_id on public.event_attendees (user_id);
create index if not exists idx_event_attendees_status on public.event_attendees (status);

alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_post_likes enable row level security;
alter table public.community_comment_likes enable row level security;
alter table public.user_contacts enable row level security;
alter table public.direct_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.events enable row level security;
alter table public.event_attendees enable row level security;
alter table public.event_comments enable row level security;
alter table public.field_reviews enable row level security;

drop policy if exists community_posts_select_public on public.community_posts;
create policy community_posts_select_public on public.community_posts for select using (true);
drop policy if exists community_posts_insert_owner on public.community_posts;
create policy community_posts_insert_owner on public.community_posts for insert with check (auth.uid() is not null and (author_id = auth.uid() or user_id = auth.uid()));
drop policy if exists community_posts_update_authenticated on public.community_posts;
drop policy if exists community_posts_update_own on public.community_posts;
create policy community_posts_update_own on public.community_posts for update using (auth.uid() = author_id or auth.uid() = user_id) with check (auth.uid() = author_id or auth.uid() = user_id);

drop policy if exists community_comments_select_public on public.community_comments;
create policy community_comments_select_public on public.community_comments for select using (true);
drop policy if exists community_comments_insert_owner on public.community_comments;
create policy community_comments_insert_owner on public.community_comments for insert with check (auth.uid() is not null and (author_id = auth.uid() or user_id = auth.uid()));
drop policy if exists community_comments_update_authenticated on public.community_comments;
drop policy if exists community_comments_update_own on public.community_comments;
create policy community_comments_update_own on public.community_comments for update using (auth.uid() = author_id or auth.uid() = user_id) with check (auth.uid() = author_id or auth.uid() = user_id);

drop policy if exists community_post_likes_select_public on public.community_post_likes;
create policy community_post_likes_select_public on public.community_post_likes for select using (true);
drop policy if exists community_post_likes_insert_own on public.community_post_likes;
create policy community_post_likes_insert_own on public.community_post_likes for insert with check (auth.uid() = user_id);
drop policy if exists community_post_likes_delete_own on public.community_post_likes;
create policy community_post_likes_delete_own on public.community_post_likes for delete using (auth.uid() = user_id);

drop policy if exists community_comment_likes_select_public on public.community_comment_likes;
create policy community_comment_likes_select_public on public.community_comment_likes for select using (true);
drop policy if exists community_comment_likes_insert_own on public.community_comment_likes;
create policy community_comment_likes_insert_own on public.community_comment_likes for insert with check (auth.uid() = user_id);
drop policy if exists community_comment_likes_delete_own on public.community_comment_likes;
create policy community_comment_likes_delete_own on public.community_comment_likes for delete using (auth.uid() = user_id);

drop policy if exists user_contacts_select_participant on public.user_contacts;
create policy user_contacts_select_participant on public.user_contacts for select using (auth.uid() = requester_id or auth.uid() = addressee_id);
drop policy if exists user_contacts_insert_requester on public.user_contacts;
create policy user_contacts_insert_requester on public.user_contacts for insert with check (auth.uid() = requester_id);
drop policy if exists user_contacts_update_participant on public.user_contacts;
create policy user_contacts_update_participant on public.user_contacts for update using (auth.uid() = requester_id or auth.uid() = addressee_id) with check (auth.uid() = requester_id or auth.uid() = addressee_id);
drop policy if exists user_contacts_delete_participant on public.user_contacts;
create policy user_contacts_delete_participant on public.user_contacts for delete using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists direct_messages_select_participant on public.direct_messages;
create policy direct_messages_select_participant on public.direct_messages for select using (auth.uid() = sender_id or auth.uid() = recipient_id);
drop policy if exists direct_messages_insert_sender on public.direct_messages;
create policy direct_messages_insert_sender on public.direct_messages for insert with check (auth.uid() = sender_id);
drop policy if exists direct_messages_update_recipient on public.direct_messages;
drop policy if exists direct_messages_update_participant on public.direct_messages;
create policy direct_messages_update_participant on public.direct_messages for update to authenticated using (auth.uid() = sender_id or auth.uid() = recipient_id) with check (auth.uid() = sender_id or auth.uid() = recipient_id);
drop policy if exists direct_messages_delete_participant on public.direct_messages;
create policy direct_messages_delete_participant on public.direct_messages for delete to authenticated using (auth.uid() = sender_id or auth.uid() = recipient_id);

insert into storage.buckets (id, name, public)
values ('community-images', 'community-images', true)
on conflict (id) do nothing;

drop policy if exists community_images_public_read on storage.objects;
create policy community_images_public_read on storage.objects for select using (bucket_id = 'community-images');
drop policy if exists community_images_auth_insert_own on storage.objects;
create policy community_images_auth_insert_own on storage.objects for insert to authenticated with check (bucket_id = 'community-images' and split_part(name, '/', 2) = auth.uid()::text);
drop policy if exists community_images_auth_update_own on storage.objects;
create policy community_images_auth_update_own on storage.objects for update to authenticated using (bucket_id = 'community-images' and split_part(name, '/', 2) = auth.uid()::text) with check (bucket_id = 'community-images' and split_part(name, '/', 2) = auth.uid()::text);
drop policy if exists community_images_auth_delete_own on storage.objects;
create policy community_images_auth_delete_own on storage.objects for delete to authenticated using (bucket_id = 'community-images' and split_part(name, '/', 2) = auth.uid()::text);

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications for select using (auth.uid() = user_id);
drop policy if exists notifications_insert_own on public.notifications;
drop policy if exists notifications_insert_authenticated on public.notifications;
create policy notifications_insert_authenticated on public.notifications for insert to authenticated with check (true);
drop policy if exists notifications_insert_service_role on public.notifications;
create policy notifications_insert_service_role on public.notifications for insert to service_role with check (true);
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists events_select_public on public.events;
create policy events_select_public on public.events for select using (true);
drop policy if exists events_insert_host on public.events;
create policy events_insert_host on public.events for insert with check (auth.uid() = host_user_id);
drop policy if exists events_update_host on public.events;
create policy events_update_host on public.events for update using (auth.uid() = host_user_id) with check (auth.uid() = host_user_id);
drop policy if exists events_delete_host on public.events;
create policy events_delete_host on public.events for delete using (auth.uid() = host_user_id);

drop policy if exists event_attendees_select_public on public.event_attendees;
create policy event_attendees_select_public on public.event_attendees for select using (true);
drop policy if exists event_attendees_insert_self on public.event_attendees;
create policy event_attendees_insert_self on public.event_attendees for insert with check (auth.uid() = user_id);
drop policy if exists event_attendees_update_self_or_host on public.event_attendees;
create policy event_attendees_update_self_or_host on public.event_attendees for update
  using (
    auth.uid() = user_id
    or exists (select 1 from public.events e where e.id = event_id and e.host_user_id = auth.uid())
  )
  with check (
    auth.uid() = user_id
    or exists (select 1 from public.events e where e.id = event_id and e.host_user_id = auth.uid())
  );

drop policy if exists event_comments_select_public on public.event_comments;
create policy event_comments_select_public on public.event_comments for select using (true);
drop policy if exists event_comments_insert_self on public.event_comments;
create policy event_comments_insert_self on public.event_comments for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists event_comments_update_own on public.event_comments;
create policy event_comments_update_own on public.event_comments for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists event_comments_delete_own on public.event_comments;
create policy event_comments_delete_own on public.event_comments for delete to authenticated using (auth.uid() = user_id);

drop policy if exists field_reviews_select_public on public.field_reviews;
create policy field_reviews_select_public
on public.field_reviews
for select
using (true);

drop policy if exists field_reviews_manage_own on public.field_reviews;
create policy field_reviews_manage_own
on public.field_reviews
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  if to_jsonb(new) ? 'updated_at' then
    new := jsonb_populate_record(
      new,
      jsonb_set(to_jsonb(new), '{updated_at}', to_jsonb(now()))
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_community_posts_set_updated_at on public.community_posts;
create trigger trg_community_posts_set_updated_at before update on public.community_posts for each row execute function public.set_updated_at();
drop trigger if exists trg_community_comments_set_updated_at on public.community_comments;
create trigger trg_community_comments_set_updated_at before update on public.community_comments for each row execute function public.set_updated_at();
drop trigger if exists trg_user_contacts_set_updated_at on public.user_contacts;
create trigger trg_user_contacts_set_updated_at before update on public.user_contacts for each row execute function public.set_updated_at();
drop trigger if exists trg_notifications_set_updated_at on public.notifications;
create trigger trg_notifications_set_updated_at before update on public.notifications for each row execute function public.set_updated_at();
drop trigger if exists trg_events_set_updated_at on public.events;
create trigger trg_events_set_updated_at before update on public.events for each row execute function public.set_updated_at();
drop trigger if exists trg_event_attendees_set_updated_at on public.event_attendees;
create trigger trg_event_attendees_set_updated_at before update on public.event_attendees for each row execute function public.set_updated_at();
drop trigger if exists trg_event_comments_set_updated_at on public.event_comments;
create trigger trg_event_comments_set_updated_at before update on public.event_comments for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------
-- MIGRATION 005: Admin roles, bans, moderation, official content
-- ---------------------------------------------------------------

create extension if not exists pgcrypto;

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
security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_roles ar where ar.user_id = admin_user_id);
$$;

-- Profiles: allow all authenticated users to browse public profiles
-- Keep existing own-profile read policies if they exist; add broad authenticated read.
drop policy if exists "Authenticated users can read profiles" on public.profiles;
create policy "Authenticated users can read profiles"
on public.profiles
for select
to authenticated
using (true);

-- admin_roles
-- Any admin can read admin roles. Insert/update/delete are admin-only; bootstrap is done manually in SQL.
drop policy if exists admin_roles_select_admin on public.admin_roles;
create policy admin_roles_select_admin on public.admin_roles for select to authenticated using (public.is_admin(auth.uid()));
drop policy if exists admin_roles_insert_admin on public.admin_roles;
create policy admin_roles_insert_admin on public.admin_roles for insert to authenticated with check (public.is_admin(auth.uid()));
drop policy if exists admin_roles_update_admin on public.admin_roles;
create policy admin_roles_update_admin on public.admin_roles for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));
drop policy if exists admin_roles_delete_admin on public.admin_roles;
create policy admin_roles_delete_admin on public.admin_roles for delete to authenticated using (public.is_admin(auth.uid()));

-- user_bans
-- Admins can manage bans. Users can read only their own ban rows.
drop policy if exists user_bans_select_admin_or_self on public.user_bans;
create policy user_bans_select_admin_or_self on public.user_bans for select to authenticated using (public.is_admin(auth.uid()) or auth.uid() = user_id);
drop policy if exists user_bans_insert_admin on public.user_bans;
create policy user_bans_insert_admin on public.user_bans for insert to authenticated with check (public.is_admin(auth.uid()) and issued_by = auth.uid());
drop policy if exists user_bans_update_admin on public.user_bans;
create policy user_bans_update_admin on public.user_bans for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));
drop policy if exists user_bans_delete_admin on public.user_bans;
create policy user_bans_delete_admin on public.user_bans for delete to authenticated using (public.is_admin(auth.uid()));

-- Community moderation by admins
drop policy if exists community_posts_delete_admin on public.community_posts;
create policy community_posts_delete_admin on public.community_posts for delete to authenticated using (public.is_admin(auth.uid()));
drop policy if exists community_posts_update_admin on public.community_posts;
create policy community_posts_update_admin on public.community_posts for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists community_comments_delete_admin on public.community_comments;
create policy community_comments_delete_admin on public.community_comments for delete to authenticated using (public.is_admin(auth.uid()));
drop policy if exists community_comments_update_admin on public.community_comments;
create policy community_comments_update_admin on public.community_comments for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- Events moderation + official events by admins
drop policy if exists events_admin_insert on public.events;
create policy events_admin_insert on public.events for insert to authenticated with check (public.is_admin(auth.uid()));
drop policy if exists events_admin_update on public.events;
create policy events_admin_update on public.events for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));
drop policy if exists events_admin_delete on public.events;
create policy events_admin_delete on public.events for delete to authenticated using (public.is_admin(auth.uid()));

drop policy if exists event_comments_delete_admin on public.event_comments;
create policy event_comments_delete_admin on public.event_comments for delete to authenticated using (public.is_admin(auth.uid()));
drop policy if exists event_comments_update_admin on public.event_comments;
create policy event_comments_update_admin on public.event_comments for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- Fields admin management
drop policy if exists fields_admin_insert on public.fields;
create policy fields_admin_insert on public.fields for insert to authenticated with check (public.is_admin(auth.uid()));
drop policy if exists fields_admin_update on public.fields;
create policy fields_admin_update on public.fields for update to authenticated using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));
drop policy if exists fields_admin_delete on public.fields;
create policy fields_admin_delete on public.fields for delete to authenticated using (public.is_admin(auth.uid()));

-- ---------------------------------------------------------------
-- MIGRATION 010 (subset): Trust and Safety foundations
-- ---------------------------------------------------------------

create table if not exists public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null,
  target_id uuid,
  reason_category text not null,
  details text,
  status text not null default 'open',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (target_type in ('user', 'post', 'comment', 'event', 'dm', 'field', 'other')),
  check (
    reason_category in (
      'spam',
      'harassment',
      'hate',
      'nudity',
      'violence',
      'illegal',
      'scam',
      'self_harm',
      'other'
    )
  ),
  check (status in ('open', 'triaged', 'actioned', 'dismissed'))
);

create index if not exists idx_safety_reports_reporter
  on public.safety_reports (reporter_user_id, created_at desc);
create index if not exists idx_safety_reports_status
  on public.safety_reports (status, created_at desc);
create index if not exists idx_safety_reports_target
  on public.safety_reports (target_type, target_id);

create table if not exists public.user_blocks (
  user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);

create index if not exists idx_user_blocks_blocked
  on public.user_blocks (blocked_user_id, created_at desc);

create table if not exists public.user_mutes (
  user_id uuid not null references auth.users(id) on delete cascade,
  muted_user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz,
  reason text,
  created_at timestamptz not null default now(),
  primary key (user_id, muted_user_id),
  check (user_id <> muted_user_id)
);

create table if not exists public.moderation_queue (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.safety_reports(id) on delete set null,
  target_type text not null,
  target_id uuid,
  priority text not null default 'normal',
  status text not null default 'queued',
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (priority in ('low', 'normal', 'high', 'critical')),
  check (status in ('queued', 'in_review', 'resolved'))
);

create index if not exists idx_moderation_queue_status_priority
  on public.moderation_queue (status, priority, created_at asc);

create or replace function public.enqueue_safety_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.moderation_queue (
    report_id,
    target_type,
    target_id,
    priority,
    status
  )
  values (
    new.id,
    new.target_type,
    new.target_id,
    'normal',
    'queued'
  );

  return new;
end;
$$;

drop trigger if exists trg_enqueue_safety_report on public.safety_reports;
create trigger trg_enqueue_safety_report
after insert on public.safety_reports
for each row
execute function public.enqueue_safety_report();

create table if not exists public.moderation_audit_logs (
  id uuid primary key default gen_random_uuid(),
  moderator_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  report_id uuid references public.safety_reports(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_moderation_audit_logs_created
  on public.moderation_audit_logs (created_at desc);

alter table public.safety_reports enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_mutes enable row level security;
alter table public.moderation_queue enable row level security;
alter table public.moderation_audit_logs enable row level security;

drop policy if exists safety_reports_select_own_or_admin on public.safety_reports;
create policy safety_reports_select_own_or_admin
on public.safety_reports for select to authenticated
using (reporter_user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists safety_reports_insert_reporter on public.safety_reports;
create policy safety_reports_insert_reporter
on public.safety_reports for insert to authenticated
with check (reporter_user_id = auth.uid());

drop policy if exists safety_reports_update_admin on public.safety_reports;
create policy safety_reports_update_admin
on public.safety_reports for update to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists user_blocks_manage_own on public.user_blocks;
create policy user_blocks_manage_own
on public.user_blocks for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists user_mutes_manage_own on public.user_mutes;
create policy user_mutes_manage_own
on public.user_mutes for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists moderation_queue_admin_only on public.moderation_queue;
create policy moderation_queue_admin_only
on public.moderation_queue for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists moderation_audit_logs_admin_only on public.moderation_audit_logs;
create policy moderation_audit_logs_admin_only
on public.moderation_audit_logs for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- ---------------------------------------------------------------
-- OPTIONAL SEED: First admin user
-- Replace the email below with your own login email before running.
-- ---------------------------------------------------------------
insert into public.admin_roles (user_id, role, created_by)
select u.id, 'admin', u.id
from auth.users u
where lower(u.email) = lower('my.computer.83@gmail.com')
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------
-- SANITY CHECKS: Trust and Safety trigger + policies
-- Run these manually after schema setup. Replace placeholders first.
-- ---------------------------------------------------------------

-- 1) As a regular authenticated user, insert a report.
-- Expected: insert succeeds.
-- insert into public.safety_reports (
--   reporter_user_id,
--   target_type,
--   target_id,
--   reason_category,
--   details
-- )
-- values (
--   auth.uid(),
--   'post',
--   '00000000-0000-0000-0000-000000000000'::uuid,
--   'spam',
--   'Sanity-check report row'
-- )
-- returning id;

-- 2) Confirm trigger queued moderation work item.
-- Expected: exactly one queued row tied to report_id.
-- select mq.*
-- from public.moderation_queue mq
-- where mq.report_id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;

-- 3) Verify reporter read access.
-- Expected: reporter can read own row.
-- select *
-- from public.safety_reports
-- where id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;

-- 4) Verify non-admin cannot read moderation queue.
-- Expected: 0 rows (or permission denied based on client context).
-- select *
-- from public.moderation_queue
-- where report_id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;

-- 5) As admin, triage report and queue item.
-- Expected: updates succeed only for admin.
-- update public.safety_reports
-- set status = 'triaged', reviewed_by = auth.uid(), reviewed_at = now()
-- where id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;
--
-- update public.moderation_queue
-- set status = 'in_review', assigned_to = auth.uid()
-- where report_id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;

-- 6) Confirm audit logging path is writable for admin only.
-- insert into public.moderation_audit_logs (
--   moderator_user_id,
--   action,
--   target_type,
--   target_id,
--   report_id,
--   notes
-- )
-- values (
--   auth.uid(),
--   'triage',
--   'post',
--   '00000000-0000-0000-0000-000000000000'::uuid,
--   'PASTE_REPORT_ID_FROM_STEP_1'::uuid,
--   'Sanity-check moderation audit write'
-- );

-- 7) Cleanup sanity-check data (run as admin when done).
-- delete from public.moderation_audit_logs
-- where report_id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;
--
-- delete from public.moderation_queue
-- where report_id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;
--
-- delete from public.safety_reports
-- where id = 'PASTE_REPORT_ID_FROM_STEP_1'::uuid;


-- ===============================================================
-- Optional seed data (shops + fields)
-- Source: 011_seed_shops_and_fields.sql
-- ===============================================================

-- 011_seed_shops_and_fields.sql
-- Idempotent seed data for initial Japan directory content.
-- Safe to run multiple times (dedupes by case-insensitive name).

insert into public.shops (
  name,
  address,
  prefecture,
  city,
  opening_times,
  phone_number,
  features,
  image_url,
  latitude,
  longitude,
  is_official
)
select
  seed.name,
  seed.address,
  seed.prefecture,
  seed.city,
  seed.opening_times,
  seed.phone_number,
  seed.features,
  seed.image_url,
  seed.latitude,
  seed.longitude,
  seed.is_official
from (
  values
    (
      'ECHIGOYA Akihabara',
      'Sotokanda 3-8-9, Chiyoda-ku, Tokyo',
      'Tokyo',
      'Chiyoda',
      'Mon-Sun 11:00-20:00',
      '+81-3-3257-8088',
      'Large AEG wall, GBB pistols, optics, parts, English-friendly staff',
      null,
      35.7024,
      139.7712,
      true
    ),
    (
      'FIRST Tokyo Arms',
      'Shibuya 2-22-3, Shibuya-ku, Tokyo',
      'Tokyo',
      'Shibuya',
      'Mon-Sat 12:00-20:00, Sun 12:00-19:00',
      '+81-3-1234-5678',
      'Tech bench, custom tuning, MOSFET installs, HPA fitting',
      null,
      35.6591,
      139.7037,
      false
    ),
    (
      'LayLax Osaka Store',
      'Nipponbashi 4-7-19, Naniwa-ku, Osaka',
      'Osaka',
      'Naniwa',
      'Tue-Sun 11:00-20:00',
      '+81-6-6648-5550',
      'LayLax parts, tactical gear, repair desk, chrono station',
      null,
      34.6561,
      135.5050,
      true
    ),
    (
      'GUN SHOP SYSTEM',
      'Tenjin 3-6-12, Chuo-ku, Fukuoka',
      'Fukuoka',
      'Fukuoka',
      'Mon-Sat 11:00-20:00, Sun 11:00-18:00',
      '+81-92-555-1048',
      'CQB-focused inventory, magazines, batteries, gas refills',
      null,
      33.5905,
      130.4017,
      false
    ),
    (
      'SAPPORO Survival Shop North',
      'Kita 24-jo Nishi 5-1-10, Kita-ku, Sapporo',
      'Hokkaido',
      'Sapporo',
      'Wed-Mon 12:00-19:00',
      '+81-11-600-2424',
      'Cold-weather setup advice, winter gas solutions, optics',
      null,
      43.0909,
      141.3469,
      false
    ),
    (
      'Nagoya Tactical Outlet',
      'Osu 3-20-14, Naka-ku, Nagoya',
      'Aichi',
      'Nagoya',
      'Mon-Sun 11:00-20:00',
      '+81-52-211-0921',
      'Outlet pricing, beginner starter kits, rental recommendations',
      null,
      35.1595,
      136.9066,
      false
    ),
    (
      'Yokohama Airsoft Garage',
      'Motomachi 1-42, Naka-ku, Yokohama',
      'Kanagawa',
      'Yokohama',
      'Tue-Sun 12:00-20:00',
      '+81-45-681-4011',
      'Internal upgrades, LiPo safety products, slings and plate carriers',
      null,
      35.4435,
      139.6490,
      false
    ),
    (
      'Okinawa Ranger Pro Shop',
      'Mihama 2-2-1, Chatan-cho, Nakagami-gun, Okinawa',
      'Okinawa',
      'Chatan',
      'Mon-Sun 10:00-19:00',
      '+81-98-936-8850',
      'Outdoor field supplies, hydration gear, helmets, gloves',
      null,
      26.3188,
      127.7578,
      false
    )
) as seed(
  name,
  address,
  prefecture,
  city,
  opening_times,
  phone_number,
  features,
  image_url,
  latitude,
  longitude,
  is_official
)
where not exists (
  select 1
  from public.shops s
  where lower(s.name) = lower(seed.name)
);

insert into public.fields (
  name,
  location_name,
  prefecture,
  city,
  latitude,
  longitude,
  field_type,
  description,
  feature_list,
  pros_list,
  cons_list,
  phone,
  email,
  website,
  instagram,
  facebook,
  x,
  youtube,
  image_url
)
select
  seed.name,
  seed.location_name,
  seed.prefecture,
  seed.city,
  seed.latitude,
  seed.longitude,
  seed.field_type,
  seed.description,
  seed.feature_list,
  seed.pros_list,
  seed.cons_list,
  seed.phone,
  seed.email,
  seed.website,
  seed.instagram,
  seed.facebook,
  seed.x,
  seed.youtube,
  seed.image_url
from (
  values
    (
      'RAID Chiba North',
      'Noda',
      'Chiba',
      'Noda',
      35.9632,
      139.8689,
      'Outdoor',
      'Woodland-style field with mixed cover and objective-based game modes.',
      'Safe zone, Rental AEGs, Chrono station, Parking, Shop counter',
      'Good map flow, beginner friendly staff, clear safety briefings',
      'Busy on weekends, lunch queue can get long',
      '+81-4-7190-1201',
      'info@raidchibanorth.jp',
      'https://example.com/raid-chiba-north',
      '@raidchibanorth',
      'RAID Chiba North',
      '@raidchibanorth',
      'RAID Chiba North Channel',
      null
    ),
    (
      'CQB Matrix Tokyo',
      'Adachi',
      'Tokyo',
      'Adachi',
      35.7788,
      139.7802,
      'CQB',
      'Indoor CQB arena with modular barricade layout and night games.',
      'Indoor arena, Rental masks, Tracer-friendly lighting, Pro shop',
      'Great for small teams, weather proof, close to station',
      'Can feel cramped for large groups',
      '+81-3-6802-4412',
      'hello@cqbmatrix.tokyo',
      'https://example.com/cqb-matrix-tokyo',
      '@cqbmatrixtokyo',
      'CQB Matrix Tokyo',
      '@cqbmatrixtokyo',
      'CQB Matrix Tokyo',
      null
    ),
    (
      'Kawasaki Frontline Field',
      'Kawasaki',
      'Kanagawa',
      'Kawasaki',
      35.5308,
      139.7031,
      'Mixed',
      'Mixed indoor and outdoor zones suitable for all-year play.',
      'Mixed map, Rental kit, On-site tech, Rest area, Vending',
      'Good transport links, balanced map design',
      'Limited parking spots',
      '+81-44-200-7730',
      'contact@frontline-kawasaki.jp',
      'https://example.com/frontline-kawasaki',
      '@frontlinekawasaki',
      'Kawasaki Frontline Field',
      '@frontlinekawasaki',
      'Kawasaki Frontline',
      null
    ),
    (
      'Osaka Industrial Zone',
      'Sakai',
      'Osaka',
      'Sakai',
      34.5732,
      135.4828,
      'CQB',
      'Industrial-themed CQB map with rotating objective scenarios.',
      'CQB lanes, Smoke grenades allowed, Rental packs, Night sessions',
      'High-intensity rounds, tactical map variety',
      'Not ideal for very young players',
      '+81-72-222-3800',
      'play@osaka-industrial.jp',
      'https://example.com/osaka-industrial-zone',
      '@osakaindustrialzone',
      'Osaka Industrial Zone',
      '@osakaindustrialzone',
      'Osaka Industrial Zone',
      null
    ),
    (
      'Fuji Outdoor Combat Park',
      'Gotemba',
      'Shizuoka',
      'Gotemba',
      35.3157,
      138.9381,
      'Outdoor',
      'Large outdoor field near Mt. Fuji with elevation changes and long lanes.',
      'Sniper lanes, Safe zone, Camping option, BBQ area, Pro shop',
      'Scenic views, great for all-day events',
      'Windy conditions some days',
      '+81-550-80-4455',
      'bookings@fuji-combat.jp',
      'https://example.com/fuji-outdoor-combat-park',
      '@fujicombatpark',
      'Fuji Outdoor Combat Park',
      '@fujicombatpark',
      'Fuji Outdoor Combat Park',
      null
    ),
    (
      'Nagoya Urban Strike',
      'Nagoya',
      'Aichi',
      'Nagoya',
      35.1740,
      136.9031,
      'Indoor',
      'Urban-style indoor site focused on speedsoft and short matches.',
      'Indoor map, Speedsoft nights, Tech bench, Battery charging',
      'Fast rounds, central location',
      'Can be noisy during peak hours',
      '+81-52-433-7610',
      'staff@urbanstrike-nagoya.jp',
      'https://example.com/nagoya-urban-strike',
      '@urbanstrike_nagoya',
      'Nagoya Urban Strike',
      '@urbanstrike_nagoya',
      'Nagoya Urban Strike',
      null
    ),
    (
      'Fukuoka Delta Field',
      'Fukuoka',
      'Fukuoka',
      'Fukuoka',
      33.5903,
      130.4010,
      'Mixed',
      'Balanced mixed terrain with both close-range and medium-range engagements.',
      'Mixed map, Family day events, Rental sets, Light snacks',
      'Friendly atmosphere, suitable for beginners',
      'Rain can affect outdoor lanes',
      '+81-92-710-2844',
      'delta@fukuoka-field.jp',
      'https://example.com/fukuoka-delta-field',
      '@fukuokadeltafield',
      'Fukuoka Delta Field',
      '@fukuokadeltafield',
      'Fukuoka Delta Field',
      null
    ),
    (
      'Sapporo Snow Wolf Field',
      'Sapporo',
      'Hokkaido',
      'Sapporo',
      43.0621,
      141.3544,
      'Outdoor',
      'Seasonal outdoor field with winter-safe game formats and heated rest area.',
      'Heated safe zone, Rental outerwear, Chrono checks, Parking',
      'Unique winter gameplay, helpful marshals',
      'Short daylight in winter',
      '+81-11-210-6631',
      'info@snowwolf-field.jp',
      'https://example.com/sapporo-snow-wolf-field',
      '@snowwolffield',
      'Sapporo Snow Wolf Field',
      '@snowwolffield',
      'Sapporo Snow Wolf Field',
      null
    )
) as seed(
  name,
  location_name,
  prefecture,
  city,
  latitude,
  longitude,
  field_type,
  description,
  feature_list,
  pros_list,
  cons_list,
  phone,
  email,
  website,
  instagram,
  facebook,
  x,
  youtube,
  image_url
)
where not exists (
  select 1
  from public.fields f
  where lower(f.name) = lower(seed.name)
);


-- ===============================================================
-- Shops + Fields hardening
-- Source: 012_shops_fields_hardening.sql
-- ===============================================================

-- 012_shops_fields_hardening.sql
-- Hardening for shops/fields directory data integrity and admin controls.

-- Ensure extension availability for gen_random_uuid and related helpers.
create extension if not exists pgcrypto;

-- ------------------------------------------------------------------
-- 1) updated_at support for shops
-- ------------------------------------------------------------------
alter table public.shops
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.set_shops_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shops_set_updated_at on public.shops;
create trigger trg_shops_set_updated_at
before update on public.shops
for each row
execute function public.set_shops_updated_at();

-- ------------------------------------------------------------------
-- 2) Name uniqueness (case-insensitive) for shops + fields
-- ------------------------------------------------------------------
-- Clean duplicates first so unique index creation is deterministic.
with ranked as (
  select
    id,
    row_number() over (
      partition by lower(name)
      order by created_at asc, id asc
    ) as rn
  from public.shops
)
delete from public.shops s
using ranked r
where s.id = r.id
  and r.rn > 1;

with ranked as (
  select
    id,
    row_number() over (
      partition by lower(name)
      order by created_at asc, id asc
    ) as rn
  from public.fields
)
delete from public.fields f
using ranked r
where f.id = r.id
  and r.rn > 1;

create unique index if not exists idx_shops_name_lower_unique
  on public.shops ((lower(name)));

create unique index if not exists idx_fields_name_lower_unique
  on public.fields ((lower(name)));

-- ------------------------------------------------------------------
-- 3) RLS policies for shops (public read, admin write)
-- ------------------------------------------------------------------
alter table public.shops enable row level security;

drop policy if exists "shops are publicly readable" on public.shops;
drop policy if exists shops_select_public on public.shops;
create policy shops_select_public
on public.shops
for select
using (true);

drop policy if exists shops_admin_insert on public.shops;
create policy shops_admin_insert
on public.shops
for insert
to authenticated
with check (public.is_admin(auth.uid()));

drop policy if exists shops_admin_update on public.shops;
create policy shops_admin_update
on public.shops
for update
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists shops_admin_delete on public.shops;
create policy shops_admin_delete
on public.shops
for delete
to authenticated
using (public.is_admin(auth.uid()));


-- ------------------------------------------------------------------
-- SANITY CHECKS: shops + fields directories
-- ------------------------------------------------------------------
-- Expected: counts are >= seeded values after running seed script.
-- select count(*) as shops_count from public.shops;
-- select count(*) as fields_count from public.fields;

-- Expected: no duplicate names (case-insensitive).
-- select lower(name) as normalized_name, count(*)
-- from public.shops
-- group by lower(name)
-- having count(*) > 1;

-- select lower(name) as normalized_name, count(*)
-- from public.fields
-- group by lower(name)
-- having count(*) > 1;

-- Expected: admin can insert/update/delete; non-admin is read-only.
