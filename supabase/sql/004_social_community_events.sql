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

-- ------------------------------------------------------------
-- Social contacts + direct messages
-- ------------------------------------------------------------
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

create index if not exists idx_direct_messages_sender_id
  on public.direct_messages (sender_id, created_at desc);
create index if not exists idx_direct_messages_recipient_id
  on public.direct_messages (recipient_id, created_at desc);
create index if not exists idx_direct_messages_unread
  on public.direct_messages (recipient_id, read_at)
  where read_at is null;

drop view if exists public.direct_message_threads;

create view public.direct_message_threads as
with base as (
  select
    dm.sender_id,
    dm.recipient_id,
    dm.body,
    dm.created_at,
    dm.read_at,
    case
      when dm.sender_id = auth.uid() then dm.recipient_id
      else dm.sender_id
    end as other_user_id
  from public.direct_messages dm
  where dm.sender_id = auth.uid() or dm.recipient_id = auth.uid()
), ranked as (
  select
    b.*,
    row_number() over (
      partition by b.other_user_id
      order by b.created_at desc
    ) as rn
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

-- ------------------------------------------------------------
-- Notifications
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);

create index if not exists idx_events_starts_at
  on public.events (starts_at asc);
create index if not exists idx_events_host_user_id
  on public.events (host_user_id);

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

alter table public.event_attendees
  add column if not exists confirmed_by_host boolean not null default false;
alter table public.event_attendees
  add column if not exists confirmed_at timestamptz;

alter table public.community_posts
  add column if not exists updated_at timestamptz not null default now();
alter table public.community_comments
  add column if not exists updated_at timestamptz not null default now();
alter table public.user_contacts
  add column if not exists updated_at timestamptz not null default now();
alter table public.notifications
  add column if not exists updated_at timestamptz not null default now();
alter table public.events
  add column if not exists updated_at timestamptz not null default now();
alter table public.event_attendees
  add column if not exists updated_at timestamptz not null default now();

alter table public.community_comments
  add column if not exists parent_comment_id uuid references public.community_comments(id) on delete cascade;

create index if not exists idx_event_attendees_event_id
  on public.event_attendees (event_id);
create index if not exists idx_event_attendees_user_id
  on public.event_attendees (user_id);
create index if not exists idx_event_attendees_status
  on public.event_attendees (status);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_post_likes enable row level security;
alter table public.community_comment_likes enable row level security;
alter table public.user_contacts enable row level security;
alter table public.direct_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.events enable row level security;
alter table public.event_attendees enable row level security;

-- community_posts
drop policy if exists community_posts_select_public on public.community_posts;
create policy community_posts_select_public
  on public.community_posts
  for select
  using (true);

drop policy if exists community_posts_insert_owner on public.community_posts;
create policy community_posts_insert_owner
  on public.community_posts
  for insert
  with check (auth.uid() is not null and (author_id = auth.uid() or user_id = auth.uid()));

drop policy if exists community_posts_update_authenticated on public.community_posts;
drop policy if exists community_posts_update_own on public.community_posts;
create policy community_posts_update_own
  on public.community_posts
  for update
  using (auth.uid() = author_id or auth.uid() = user_id)
  with check (auth.uid() = author_id or auth.uid() = user_id);

-- community_comments
drop policy if exists community_comments_select_public on public.community_comments;
create policy community_comments_select_public
  on public.community_comments
  for select
  using (true);

drop policy if exists community_comments_insert_owner on public.community_comments;
create policy community_comments_insert_owner
  on public.community_comments
  for insert
  with check (auth.uid() is not null and (author_id = auth.uid() or user_id = auth.uid()));

drop policy if exists community_comments_update_authenticated on public.community_comments;
drop policy if exists community_comments_update_own on public.community_comments;
create policy community_comments_update_own
  on public.community_comments
  for update
  using (auth.uid() = author_id or auth.uid() = user_id)
  with check (auth.uid() = author_id or auth.uid() = user_id);

-- community_post_likes
drop policy if exists community_post_likes_select_public on public.community_post_likes;
create policy community_post_likes_select_public
  on public.community_post_likes
  for select
  using (true);

drop policy if exists community_post_likes_insert_own on public.community_post_likes;
create policy community_post_likes_insert_own
  on public.community_post_likes
  for insert
  with check (auth.uid() = user_id);

drop policy if exists community_post_likes_delete_own on public.community_post_likes;
create policy community_post_likes_delete_own
  on public.community_post_likes
  for delete
  using (auth.uid() = user_id);

-- community_comment_likes
drop policy if exists community_comment_likes_select_public on public.community_comment_likes;
create policy community_comment_likes_select_public
  on public.community_comment_likes
  for select
  using (true);

drop policy if exists community_comment_likes_insert_own on public.community_comment_likes;
create policy community_comment_likes_insert_own
  on public.community_comment_likes
  for insert
  with check (auth.uid() = user_id);

drop policy if exists community_comment_likes_delete_own on public.community_comment_likes;
create policy community_comment_likes_delete_own
  on public.community_comment_likes
  for delete
  using (auth.uid() = user_id);

-- user_contacts
drop policy if exists user_contacts_select_participant on public.user_contacts;
create policy user_contacts_select_participant
  on public.user_contacts
  for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists user_contacts_insert_requester on public.user_contacts;
create policy user_contacts_insert_requester
  on public.user_contacts
  for insert
  with check (auth.uid() = requester_id);

drop policy if exists user_contacts_update_participant on public.user_contacts;
create policy user_contacts_update_participant
  on public.user_contacts
  for update
  using (auth.uid() = requester_id or auth.uid() = addressee_id)
  with check (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists user_contacts_delete_participant on public.user_contacts;
create policy user_contacts_delete_participant
  on public.user_contacts
  for delete
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- direct_messages
drop policy if exists direct_messages_select_participant on public.direct_messages;
create policy direct_messages_select_participant
  on public.direct_messages
  for select
  using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists direct_messages_insert_sender on public.direct_messages;
create policy direct_messages_insert_sender
  on public.direct_messages
  for insert
  with check (auth.uid() = sender_id);

drop policy if exists direct_messages_update_recipient on public.direct_messages;
create policy direct_messages_update_recipient
  on public.direct_messages
  for update
  using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

-- notifications
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications
  for select
  using (auth.uid() = user_id);

drop policy if exists notifications_insert_own on public.notifications;
drop policy if exists notifications_insert_authenticated on public.notifications;
create policy notifications_insert_authenticated
  on public.notifications
  for insert
  to authenticated
  with check (true);

drop policy if exists notifications_insert_service_role on public.notifications;
create policy notifications_insert_service_role
  on public.notifications
  for insert
  to service_role
  with check (true);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
  on public.notifications
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- events
drop policy if exists events_select_public on public.events;
create policy events_select_public
  on public.events
  for select
  using (true);

drop policy if exists events_insert_host on public.events;
create policy events_insert_host
  on public.events
  for insert
  with check (auth.uid() = host_user_id);

drop policy if exists events_update_host on public.events;
create policy events_update_host
  on public.events
  for update
  using (auth.uid() = host_user_id)
  with check (auth.uid() = host_user_id);

drop policy if exists events_delete_host on public.events;
create policy events_delete_host
  on public.events
  for delete
  using (auth.uid() = host_user_id);

-- event_attendees
drop policy if exists event_attendees_select_public on public.event_attendees;
create policy event_attendees_select_public
  on public.event_attendees
  for select
  using (true);

drop policy if exists event_attendees_insert_self on public.event_attendees;
create policy event_attendees_insert_self
  on public.event_attendees
  for insert
  with check (auth.uid() = user_id);

drop policy if exists event_attendees_update_self_or_host on public.event_attendees;
create policy event_attendees_update_self_or_host
  on public.event_attendees
  for update
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.events e
      where e.id = event_id and e.host_user_id = auth.uid()
    )
  )
  with check (
    auth.uid() = user_id
    or exists (
      select 1
      from public.events e
      where e.id = event_id and e.host_user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- updated_at helper trigger
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_community_posts_set_updated_at on public.community_posts;
create trigger trg_community_posts_set_updated_at
before update on public.community_posts
for each row execute function public.set_updated_at();

drop trigger if exists trg_community_comments_set_updated_at on public.community_comments;
create trigger trg_community_comments_set_updated_at
before update on public.community_comments
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_contacts_set_updated_at on public.user_contacts;
create trigger trg_user_contacts_set_updated_at
before update on public.user_contacts
for each row execute function public.set_updated_at();

drop trigger if exists trg_notifications_set_updated_at on public.notifications;
create trigger trg_notifications_set_updated_at
before update on public.notifications
for each row execute function public.set_updated_at();

drop trigger if exists trg_events_set_updated_at on public.events;
create trigger trg_events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();

drop trigger if exists trg_event_attendees_set_updated_at on public.event_attendees;
create trigger trg_event_attendees_set_updated_at
before update on public.event_attendees
for each row execute function public.set_updated_at();
