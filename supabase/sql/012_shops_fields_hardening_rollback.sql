-- 012_shops_fields_hardening_rollback.sql
-- Rollback companion for 012_shops_fields_hardening.sql.
-- Intended for non-production/testing rollback workflows.

-- ------------------------------------------------------------------
-- 1) Roll back shops RLS policies
-- ------------------------------------------------------------------
drop policy if exists shops_admin_delete on public.shops;
drop policy if exists shops_admin_update on public.shops;
drop policy if exists shops_admin_insert on public.shops;
drop policy if exists shops_select_public on public.shops;

-- Restore original read-only policy name used by 010_shops.sql.
create policy "shops are publicly readable"
  on public.shops for select using (true);

-- ------------------------------------------------------------------
-- 2) Roll back uniqueness constraints added in 012
-- ------------------------------------------------------------------
drop index if exists public.idx_shops_name_lower_unique;
drop index if exists public.idx_fields_name_lower_unique;

-- ------------------------------------------------------------------
-- 3) Roll back shops updated_at trigger/function/column
-- ------------------------------------------------------------------
drop trigger if exists trg_shops_set_updated_at on public.shops;
drop function if exists public.set_shops_updated_at();

-- Remove column last, after dropping trigger/function references.
alter table public.shops
  drop column if exists updated_at;

-- ------------------------------------------------------------------
-- 4) Optional note
-- ------------------------------------------------------------------
-- This rollback does not restore duplicate rows that may have been deleted
-- by 012_shops_fields_hardening.sql cleanup step.
