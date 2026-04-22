-- 013_push_delivery_pipeline.sql
-- Device push pipeline foundations for app notifications.

create extension if not exists pgcrypto;

-- ------------------------------------------------------------------
-- 1) Normalize device token storage for active device management
-- ------------------------------------------------------------------
alter table public.device_tokens
  add column if not exists device_name text;

alter table public.device_tokens
  add column if not exists is_active boolean not null default true;

alter table public.device_tokens
  add column if not exists last_seen_at timestamptz not null default now();

create index if not exists idx_device_tokens_user_active
  on public.device_tokens (user_id, is_active, updated_at desc);

create index if not exists idx_device_tokens_active_token
  on public.device_tokens (token)
  where is_active = true;

-- ------------------------------------------------------------------
-- 2) Push jobs queue generated from notifications table
-- ------------------------------------------------------------------
create table if not exists public.notification_push_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text,
  title text not null,
  body text not null,
  data_json jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('pending', 'processing', 'sent', 'failed')),
  unique (notification_id, token)
);

create index if not exists idx_notification_push_jobs_pending
  on public.notification_push_jobs (status, created_at asc)
  where status in ('pending', 'failed');

create index if not exists idx_notification_push_jobs_user
  on public.notification_push_jobs (user_id, created_at desc);

create or replace function public.enqueue_push_jobs_for_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_push_jobs (
    notification_id,
    user_id,
    token,
    platform,
    title,
    body,
    data_json,
    status
  )
  select
    new.id,
    new.user_id,
    dt.token,
    dt.platform,
    new.title,
    new.body,
    jsonb_strip_nulls(
      jsonb_build_object(
        'notification_id', new.id,
        'type', new.type,
        'entity_id', new.entity_id,
        'actor_user_id', new.actor_user_id
      )
    ),
    'pending'
  from public.device_tokens dt
  where dt.user_id = new.user_id
    and coalesce(dt.is_active, true) = true
    and dt.token is not null
    and btrim(dt.token) <> ''
  on conflict (notification_id, token) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_enqueue_push_jobs_for_notification on public.notifications;
create trigger trg_enqueue_push_jobs_for_notification
after insert on public.notifications
for each row
execute function public.enqueue_push_jobs_for_notification();

-- ------------------------------------------------------------------
-- 3) Updated-at trigger for push jobs
-- ------------------------------------------------------------------
create or replace function public.set_notification_push_jobs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_notification_push_jobs_set_updated_at on public.notification_push_jobs;
create trigger trg_notification_push_jobs_set_updated_at
before update on public.notification_push_jobs
for each row
execute function public.set_notification_push_jobs_updated_at();

-- ------------------------------------------------------------------
-- 4) RLS policies
-- ------------------------------------------------------------------
alter table public.notification_push_jobs enable row level security;

drop policy if exists notification_push_jobs_select_own on public.notification_push_jobs;
create policy notification_push_jobs_select_own
on public.notification_push_jobs
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists notification_push_jobs_insert_service on public.notification_push_jobs;
create policy notification_push_jobs_insert_service
on public.notification_push_jobs
for insert
to service_role
with check (true);

drop policy if exists notification_push_jobs_update_service on public.notification_push_jobs;
create policy notification_push_jobs_update_service
on public.notification_push_jobs
for update
to service_role
using (true)
with check (true);

-- ------------------------------------------------------------------
-- 5) Helpful comments for operators
-- ------------------------------------------------------------------
comment on table public.notification_push_jobs is
  'Queue of push delivery attempts derived from app notifications. A worker/edge function should claim and send pending jobs via FCM/APNs.';
