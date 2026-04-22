-- 013_push_delivery_pipeline_rollback.sql
-- Rollback companion for 013_push_delivery_pipeline.sql.

-- ------------------------------------------------------------------
-- 1) Remove push jobs policies/triggers/functions/table
-- ------------------------------------------------------------------
drop trigger if exists trg_enqueue_push_jobs_for_notification on public.notifications;
drop function if exists public.enqueue_push_jobs_for_notification();

drop trigger if exists trg_notification_push_jobs_set_updated_at on public.notification_push_jobs;
drop function if exists public.set_notification_push_jobs_updated_at();

drop policy if exists notification_push_jobs_update_service on public.notification_push_jobs;
drop policy if exists notification_push_jobs_insert_service on public.notification_push_jobs;
drop policy if exists notification_push_jobs_select_own on public.notification_push_jobs;

drop table if exists public.notification_push_jobs;

-- ------------------------------------------------------------------
-- 2) Remove device token columns/indexes added in 013
-- ------------------------------------------------------------------
drop index if exists public.idx_device_tokens_active_token;
drop index if exists public.idx_device_tokens_user_active;

alter table public.device_tokens
  drop column if exists last_seen_at,
  drop column if exists is_active,
  drop column if exists device_name;
