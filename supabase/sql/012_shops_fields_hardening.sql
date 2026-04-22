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
