-- ---------------------------------------------------------------
-- MIGRATION 010: Platform expansion foundations
-- Covers trust/safety, event waitlist/reminders, field discovery,
-- social retention, posting quality, messaging, reliability,
-- monetization, and analytics scaffolding.
-- ---------------------------------------------------------------

create extension if not exists pgcrypto;

-- =========================
-- TRUST AND SAFETY
-- =========================

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

create table if not exists public.action_rate_limit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  action_key text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_action_rate_limit_actor_action
  on public.action_rate_limit_events (actor_user_id, action_key, created_at desc);

create or replace function public.consume_rate_limit(
  p_actor_user_id uuid,
  p_action_key text,
  p_max_actions integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  used_count integer;
begin
  insert into public.action_rate_limit_events (actor_user_id, action_key)
  values (p_actor_user_id, p_action_key);

  select count(*)::int
  into used_count
  from public.action_rate_limit_events e
  where e.actor_user_id = p_actor_user_id
    and e.action_key = p_action_key
    and e.created_at >= now() - make_interval(secs => p_window_seconds);

  return used_count <= p_max_actions;
end;
$$;

-- =========================
-- STRONGER EVENT EXPERIENCE
-- =========================

create table if not exists public.event_waitlist (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'queued',
  queued_at timestamptz not null default now(),
  promoted_at timestamptz,
  unique (event_id, user_id),
  check (status in ('queued', 'promoted', 'cancelled'))
);

create index if not exists idx_event_waitlist_event_queue
  on public.event_waitlist (event_id, status, queued_at asc);

create or replace function public.promote_event_waitlist(p_event_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  max_players_count integer;
  active_attendees integer;
  available_slots integer;
  promoted_count integer := 0;
  candidate record;
begin
  select e.max_players
  into max_players_count
  from public.events e
  where e.id = p_event_id;

  if max_players_count is null then
    return 0;
  end if;

  select count(*)::int
  into active_attendees
  from public.event_attendees ea
  where ea.event_id = p_event_id
    and ea.status = 'attending';

  available_slots := greatest(max_players_count - active_attendees, 0);
  if available_slots = 0 then
    return 0;
  end if;

  for candidate in
    select ew.id, ew.user_id
    from public.event_waitlist ew
    where ew.event_id = p_event_id
      and ew.status = 'queued'
    order by ew.queued_at asc
    limit available_slots
  loop
    begin
      insert into public.event_attendees (event_id, user_id, status)
      values (p_event_id, candidate.user_id, 'attending')
      on conflict (event_id, user_id) do update
      set status = 'attending',
          updated_at = now();

      update public.event_waitlist
      set status = 'promoted',
          promoted_at = now()
      where id = candidate.id;

      promoted_count := promoted_count + 1;
    exception
      when others then
        -- Keep processing remaining waitlist entries.
        null;
    end;
  end loop;

  return promoted_count;
end;
$$;

create or replace function public.trg_promote_event_waitlist_after_attendee_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_event_id uuid;
begin
  affected_event_id := coalesce(new.event_id, old.event_id);
  if affected_event_id is not null then
    perform public.promote_event_waitlist(affected_event_id);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_promote_event_waitlist_after_attendee_change on public.event_attendees;
create trigger trg_promote_event_waitlist_after_attendee_change
after insert or update or delete on public.event_attendees
for each row execute function public.trg_promote_event_waitlist_after_attendee_change();

create table if not exists public.event_reminder_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  reminder_type text not null,
  scheduled_for timestamptz not null,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, event_id, reminder_type),
  check (reminder_type in ('24h', '2h'))
);

create index if not exists idx_event_reminder_jobs_pending
  on public.event_reminder_jobs (scheduled_for asc)
  where sent_at is null;

create table if not exists public.event_checkins (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  attendee_user_id uuid not null references auth.users(id) on delete cascade,
  checked_by_host_id uuid references auth.users(id) on delete set null,
  status text not null,
  notes text,
  created_at timestamptz not null default now(),
  unique (event_id, attendee_user_id),
  check (status in ('attended', 'no_show'))
);

create table if not exists public.event_calendar_exports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  external_calendar_id text,
  sync_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (provider in ('google', 'apple', 'ics')),
  unique (user_id, provider)
);

-- =========================
-- FIELD DISCOVERY
-- =========================

create table if not exists public.field_attributes (
  field_id uuid primary key references public.fields(id) on delete cascade,
  is_indoor boolean not null default false,
  is_outdoor boolean not null default true,
  has_cqb boolean not null default false,
  has_open_area boolean not null default false,
  rental_available boolean not null default false,
  chrono_limit_joule numeric(5, 2),
  verified_official boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.field_owner_verifications (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('pending', 'verified', 'rejected')),
  unique (field_id, owner_user_id)
);

create table if not exists public.field_photos (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text not null,
  caption text,
  captured_at timestamptz,
  uploaded_at timestamptz not null default now(),
  is_hidden boolean not null default false
);

create index if not exists idx_field_photos_field_uploaded
  on public.field_photos (field_id, uploaded_at desc);

-- =========================
-- SOCIAL GRAPH + RETENTION
-- =========================

create table if not exists public.user_follows (
  follower_user_id uuid not null references auth.users(id) on delete cascade,
  followed_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_user_id, followed_user_id),
  check (follower_user_id <> followed_user_id)
);

create table if not exists public.suggested_friends_cache (
  user_id uuid not null references auth.users(id) on delete cascade,
  suggested_user_id uuid not null references auth.users(id) on delete cascade,
  score numeric(6, 3) not null default 0,
  reason text,
  updated_at timestamptz not null default now(),
  primary key (user_id, suggested_user_id),
  check (user_id <> suggested_user_id)
);

create table if not exists public.user_activity_summaries (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  events_joined integer not null default 0,
  reviews_posted integer not null default 0,
  posts_created integer not null default 0,
  comments_created integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, week_start)
);

create table if not exists public.weekly_digest_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  payload_json jsonb not null default '{}'::jsonb,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, week_start)
);

-- =========================
-- POSTING QUALITY
-- =========================

create table if not exists public.post_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  draft_key text not null,
  post_context text not null default 'community',
  target_user_id uuid references auth.users(id) on delete set null,
  title text not null default '',
  body_text text not null default '',
  plain_text text not null default '',
  media_json jsonb not null default '[]'::jsonb,
  poll_json jsonb,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, draft_key)
);

create table if not exists public.comment_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  thread_type text not null,
  thread_id uuid not null,
  parent_comment_id uuid,
  body_text text not null default '',
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (thread_type in ('community_post', 'event'))
);

create index if not exists idx_comment_drafts_user_thread
  on public.comment_drafts (user_id, thread_type, thread_id, updated_at desc);

create table if not exists public.post_polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  question text not null,
  allow_multiple boolean not null default false,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (post_id)
);

create table if not exists public.post_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.post_polls(id) on delete cascade,
  option_text text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.post_poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.post_polls(id) on delete cascade,
  option_id uuid not null references public.post_poll_options(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (poll_id, option_id, user_id)
);

create table if not exists public.community_guidelines (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'global',
  markdown_body text not null,
  is_pinned boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (category)
);

-- =========================
-- MESSAGING IMPROVEMENTS
-- =========================

create table if not exists public.direct_message_read_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  send_read_receipts boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.direct_message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.direct_messages(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  file_url text not null,
  mime_type text,
  file_size_bytes bigint,
  created_at timestamptz not null default now()
);

create table if not exists public.direct_message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.direct_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null,
  created_at timestamptz not null default now(),
  unique (message_id, user_id, reaction)
);

create table if not exists public.direct_message_search_docs (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  other_user_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.direct_messages(id) on delete cascade,
  body_text text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_direct_message_search_docs_owner_other
  on public.direct_message_search_docs (owner_user_id, other_user_id, created_at desc);

-- =========================
-- RELIABILITY + PERFORMANCE
-- =========================

create table if not exists public.offline_action_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action_type text not null,
  payload_json jsonb not null default '{}'::jsonb,
  status text not null default 'queued',
  retry_count integer not null default 0,
  next_retry_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('queued', 'processing', 'completed', 'failed'))
);

create index if not exists idx_offline_action_queue_pending
  on public.offline_action_queue (status, next_retry_at asc, created_at asc);

create table if not exists public.cache_invalidation_telemetry (
  id uuid primary key default gen_random_uuid(),
  cache_key text not null,
  source text not null,
  stale_detected boolean not null default false,
  server_version text,
  client_version text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_cache_invalidation_telemetry_created
  on public.cache_invalidation_telemetry (created_at desc);

create table if not exists public.background_sync_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  task_name text not null,
  status text not null default 'started',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  metrics_json jsonb not null default '{}'::jsonb,
  check (status in ('started', 'success', 'failed', 'partial'))
);

create table if not exists public.system_status_incidents (
  id uuid primary key default gen_random_uuid(),
  component text not null,
  severity text not null,
  status text not null default 'investigating',
  title text not null,
  details text,
  started_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  check (severity in ('minor', 'major', 'critical')),
  check (status in ('investigating', 'identified', 'monitoring', 'resolved'))
);

-- =========================
-- MONETIZATION
-- =========================

create table if not exists public.pro_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'host_pro',
  status text not null default 'inactive',
  renews_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('inactive', 'trialing', 'active', 'past_due', 'cancelled'))
);

create table if not exists public.field_owner_analytics_snapshots (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  snapshot_date date not null,
  occupancy_rate numeric(5, 2),
  no_show_rate numeric(5, 2),
  avg_booking_lead_hours numeric(8, 2),
  metrics_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (field_id, snapshot_date)
);

create table if not exists public.event_templates (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text not null default '',
  defaults_json jsonb not null default '{}'::jsonb,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sponsored_slots (
  id uuid primary key default gen_random_uuid(),
  surface text not null,
  slot_key text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  sponsor_name text not null,
  payload_json jsonb not null default '{}'::jsonb,
  frequency_cap_per_user integer,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type text not null,
  discount_value numeric(10, 2) not null,
  max_redemptions integer,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (discount_type in ('percent', 'fixed'))
);

create table if not exists public.promo_code_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_code_id uuid not null references public.promo_codes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid references public.events(id) on delete set null,
  redeemed_at timestamptz not null default now(),
  unique (promo_code_id, user_id, event_id)
);

-- =========================
-- ANALYTICS + EXPERIMENTATION
-- =========================

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  event_name text not null,
  session_id text,
  properties_json jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists idx_analytics_events_name_time
  on public.analytics_events (event_name, occurred_at desc);

create table if not exists public.experiment_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  experiment_key text not null,
  variant_key text not null,
  assigned_at timestamptz not null default now(),
  unique (user_id, experiment_key)
);

create table if not exists public.churn_risk_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  risk_score numeric(5, 4) not null,
  signals_json jsonb not null default '{}'::jsonb,
  scored_at timestamptz not null default now()
);

create index if not exists idx_churn_risk_scores_user_scored
  on public.churn_risk_scores (user_id, scored_at desc);

-- =========================
-- RLS + POLICIES
-- =========================

alter table public.safety_reports enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_mutes enable row level security;
alter table public.moderation_queue enable row level security;
alter table public.moderation_audit_logs enable row level security;
alter table public.action_rate_limit_events enable row level security;
alter table public.event_waitlist enable row level security;
alter table public.event_reminder_jobs enable row level security;
alter table public.event_checkins enable row level security;
alter table public.event_calendar_exports enable row level security;
alter table public.field_attributes enable row level security;
alter table public.field_owner_verifications enable row level security;
alter table public.field_photos enable row level security;
alter table public.user_follows enable row level security;
alter table public.suggested_friends_cache enable row level security;
alter table public.user_activity_summaries enable row level security;
alter table public.weekly_digest_jobs enable row level security;
alter table public.post_drafts enable row level security;
alter table public.comment_drafts enable row level security;
alter table public.post_polls enable row level security;
alter table public.post_poll_options enable row level security;
alter table public.post_poll_votes enable row level security;
alter table public.community_guidelines enable row level security;
alter table public.direct_message_read_preferences enable row level security;
alter table public.direct_message_attachments enable row level security;
alter table public.direct_message_reactions enable row level security;
alter table public.direct_message_search_docs enable row level security;
alter table public.offline_action_queue enable row level security;
alter table public.cache_invalidation_telemetry enable row level security;
alter table public.background_sync_runs enable row level security;
alter table public.system_status_incidents enable row level security;
alter table public.pro_subscriptions enable row level security;
alter table public.field_owner_analytics_snapshots enable row level security;
alter table public.event_templates enable row level security;
alter table public.sponsored_slots enable row level security;
alter table public.promo_codes enable row level security;
alter table public.promo_code_redemptions enable row level security;
alter table public.analytics_events enable row level security;
alter table public.experiment_assignments enable row level security;
alter table public.churn_risk_scores enable row level security;

-- Own data access

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

drop policy if exists action_rate_limit_events_own on public.action_rate_limit_events;
create policy action_rate_limit_events_own
on public.action_rate_limit_events for select to authenticated
using (actor_user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists event_waitlist_manage_own_or_host on public.event_waitlist;
create policy event_waitlist_manage_own_or_host
on public.event_waitlist for all to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.events e
    where e.id = event_id and e.host_user_id = auth.uid()
  )
)
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.events e
    where e.id = event_id and e.host_user_id = auth.uid()
  )
);

drop policy if exists event_reminder_jobs_own on public.event_reminder_jobs;
create policy event_reminder_jobs_own
on public.event_reminder_jobs for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists event_checkins_host_or_self on public.event_checkins;
create policy event_checkins_host_or_self
on public.event_checkins for select to authenticated
using (
  attendee_user_id = auth.uid()
  or exists (
    select 1 from public.events e
    where e.id = event_id and e.host_user_id = auth.uid()
  )
);

drop policy if exists event_checkins_host_write on public.event_checkins;
create policy event_checkins_host_write
on public.event_checkins for all to authenticated
using (
  exists (
    select 1 from public.events e
    where e.id = event_id and e.host_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.events e
    where e.id = event_id and e.host_user_id = auth.uid()
  )
);

drop policy if exists event_calendar_exports_own on public.event_calendar_exports;
create policy event_calendar_exports_own
on public.event_calendar_exports for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists field_attributes_select_public on public.field_attributes;
create policy field_attributes_select_public
on public.field_attributes for select using (true);

drop policy if exists field_attributes_admin_update on public.field_attributes;
create policy field_attributes_admin_update
on public.field_attributes for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists field_owner_verifications_admin_or_owner on public.field_owner_verifications;
create policy field_owner_verifications_admin_or_owner
on public.field_owner_verifications for select to authenticated
using (owner_user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists field_owner_verifications_owner_insert on public.field_owner_verifications;
create policy field_owner_verifications_owner_insert
on public.field_owner_verifications for insert to authenticated
with check (owner_user_id = auth.uid());

drop policy if exists field_owner_verifications_admin_update on public.field_owner_verifications;
create policy field_owner_verifications_admin_update
on public.field_owner_verifications for update to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists field_photos_select_public on public.field_photos;
create policy field_photos_select_public
on public.field_photos for select using (is_hidden = false or public.is_admin(auth.uid()));

drop policy if exists field_photos_manage_own_or_admin on public.field_photos;
create policy field_photos_manage_own_or_admin
on public.field_photos for all to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()))
with check (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists user_follows_manage_own on public.user_follows;
create policy user_follows_manage_own
on public.user_follows for all to authenticated
using (follower_user_id = auth.uid())
with check (follower_user_id = auth.uid());

drop policy if exists suggested_friends_cache_own on public.suggested_friends_cache;
create policy suggested_friends_cache_own
on public.suggested_friends_cache for select to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists suggested_friends_cache_admin_write on public.suggested_friends_cache;
create policy suggested_friends_cache_admin_write
on public.suggested_friends_cache for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists user_activity_summaries_own on public.user_activity_summaries;
create policy user_activity_summaries_own
on public.user_activity_summaries for select to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists user_activity_summaries_admin_write on public.user_activity_summaries;
create policy user_activity_summaries_admin_write
on public.user_activity_summaries for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists weekly_digest_jobs_own_or_admin on public.weekly_digest_jobs;
create policy weekly_digest_jobs_own_or_admin
on public.weekly_digest_jobs for all to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()))
with check (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists post_drafts_own on public.post_drafts;
create policy post_drafts_own
on public.post_drafts for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists comment_drafts_own on public.comment_drafts;
create policy comment_drafts_own
on public.comment_drafts for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists post_polls_select_public on public.post_polls;
create policy post_polls_select_public
on public.post_polls for select using (true);

drop policy if exists post_polls_manage_owner_or_admin on public.post_polls;
create policy post_polls_manage_owner_or_admin
on public.post_polls for all to authenticated
using (
  public.is_admin(auth.uid())
  or exists (
    select 1 from public.community_posts cp
    where cp.id = post_id and (cp.author_id = auth.uid() or cp.user_id = auth.uid())
  )
)
with check (
  public.is_admin(auth.uid())
  or exists (
    select 1 from public.community_posts cp
    where cp.id = post_id and (cp.author_id = auth.uid() or cp.user_id = auth.uid())
  )
);

drop policy if exists post_poll_options_select_public on public.post_poll_options;
create policy post_poll_options_select_public
on public.post_poll_options for select using (true);

drop policy if exists post_poll_options_manage_owner_or_admin on public.post_poll_options;
create policy post_poll_options_manage_owner_or_admin
on public.post_poll_options for all to authenticated
using (
  public.is_admin(auth.uid())
  or exists (
    select 1 from public.post_polls pp
    join public.community_posts cp on cp.id = pp.post_id
    where pp.id = poll_id and (cp.author_id = auth.uid() or cp.user_id = auth.uid())
  )
)
with check (
  public.is_admin(auth.uid())
  or exists (
    select 1 from public.post_polls pp
    join public.community_posts cp on cp.id = pp.post_id
    where pp.id = poll_id and (cp.author_id = auth.uid() or cp.user_id = auth.uid())
  )
);

drop policy if exists post_poll_votes_select_public on public.post_poll_votes;
create policy post_poll_votes_select_public
on public.post_poll_votes for select using (true);

drop policy if exists post_poll_votes_manage_own on public.post_poll_votes;
create policy post_poll_votes_manage_own
on public.post_poll_votes for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists community_guidelines_select_public on public.community_guidelines;
create policy community_guidelines_select_public
on public.community_guidelines for select using (true);

drop policy if exists community_guidelines_admin_write on public.community_guidelines;
create policy community_guidelines_admin_write
on public.community_guidelines for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists dm_read_preferences_own on public.direct_message_read_preferences;
create policy dm_read_preferences_own
on public.direct_message_read_preferences for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists dm_attachments_participant on public.direct_message_attachments;
create policy dm_attachments_participant
on public.direct_message_attachments for select to authenticated
using (
  exists (
    select 1 from public.direct_messages dm
    where dm.id = message_id
      and (dm.sender_id = auth.uid() or dm.recipient_id = auth.uid())
  )
);

drop policy if exists dm_attachments_sender_insert on public.direct_message_attachments;
create policy dm_attachments_sender_insert
on public.direct_message_attachments for insert to authenticated
with check (sender_id = auth.uid());

drop policy if exists dm_attachments_sender_delete on public.direct_message_attachments;
create policy dm_attachments_sender_delete
on public.direct_message_attachments for delete to authenticated
using (sender_id = auth.uid());

drop policy if exists dm_reactions_participant_select on public.direct_message_reactions;
create policy dm_reactions_participant_select
on public.direct_message_reactions for select to authenticated
using (
  exists (
    select 1 from public.direct_messages dm
    where dm.id = message_id
      and (dm.sender_id = auth.uid() or dm.recipient_id = auth.uid())
  )
);

drop policy if exists dm_reactions_manage_own on public.direct_message_reactions;
create policy dm_reactions_manage_own
on public.direct_message_reactions for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists dm_search_docs_own on public.direct_message_search_docs;
create policy dm_search_docs_own
on public.direct_message_search_docs for all to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists offline_action_queue_own on public.offline_action_queue;
create policy offline_action_queue_own
on public.offline_action_queue for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists cache_invalidation_admin_only on public.cache_invalidation_telemetry;
create policy cache_invalidation_admin_only
on public.cache_invalidation_telemetry for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists background_sync_runs_own_or_admin on public.background_sync_runs;
create policy background_sync_runs_own_or_admin
on public.background_sync_runs for all to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()))
with check (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists system_status_select_public on public.system_status_incidents;
create policy system_status_select_public
on public.system_status_incidents for select using (true);

drop policy if exists system_status_admin_write on public.system_status_incidents;
create policy system_status_admin_write
on public.system_status_incidents for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists pro_subscriptions_own on public.pro_subscriptions;
create policy pro_subscriptions_own
on public.pro_subscriptions for select to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists pro_subscriptions_admin_write on public.pro_subscriptions;
create policy pro_subscriptions_admin_write
on public.pro_subscriptions for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists field_owner_analytics_admin_or_owner on public.field_owner_analytics_snapshots;
create policy field_owner_analytics_admin_or_owner
on public.field_owner_analytics_snapshots for select to authenticated
using (
  public.is_admin(auth.uid())
  or exists (
    select 1 from public.field_owner_verifications fov
    where fov.field_id = field_id
      and fov.owner_user_id = auth.uid()
      and fov.status = 'verified'
  )
);

drop policy if exists field_owner_analytics_admin_write on public.field_owner_analytics_snapshots;
create policy field_owner_analytics_admin_write
on public.field_owner_analytics_snapshots for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists event_templates_own on public.event_templates;
create policy event_templates_own
on public.event_templates for all to authenticated
using (host_user_id = auth.uid())
with check (host_user_id = auth.uid());

drop policy if exists sponsored_slots_select_public on public.sponsored_slots;
create policy sponsored_slots_select_public
on public.sponsored_slots for select using (is_active = true);

drop policy if exists sponsored_slots_admin_write on public.sponsored_slots;
create policy sponsored_slots_admin_write
on public.sponsored_slots for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists promo_codes_select_public on public.promo_codes;
create policy promo_codes_select_public
on public.promo_codes for select using (is_active = true);

drop policy if exists promo_codes_admin_write on public.promo_codes;
create policy promo_codes_admin_write
on public.promo_codes for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists promo_code_redemptions_own on public.promo_code_redemptions;
create policy promo_code_redemptions_own
on public.promo_code_redemptions for select to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists promo_code_redemptions_insert_own on public.promo_code_redemptions;
create policy promo_code_redemptions_insert_own
on public.promo_code_redemptions for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists analytics_events_own_or_admin on public.analytics_events;
create policy analytics_events_own_or_admin
on public.analytics_events for all to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()))
with check (user_id = auth.uid() or user_id is null or public.is_admin(auth.uid()));

drop policy if exists experiment_assignments_own_or_admin on public.experiment_assignments;
create policy experiment_assignments_own_or_admin
on public.experiment_assignments for all to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()))
with check (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists churn_scores_own_or_admin on public.churn_risk_scores;
create policy churn_scores_own_or_admin
on public.churn_risk_scores for select to authenticated
using (user_id = auth.uid() or public.is_admin(auth.uid()));

drop policy if exists churn_scores_admin_write on public.churn_risk_scores;
create policy churn_scores_admin_write
on public.churn_risk_scores for all to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

-- ---------------------------------------------------------------
-- OPTIONAL OPERATOR SANITY CHECKS: Trust and Safety trigger + RLS
-- These are commented examples for manual verification after apply.
-- Replace placeholders before running.
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
