-- Annual ad-free membership requests with admin review before payment.

create table if not exists public.ad_free_membership_requests (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null references public.profiles(id) on delete cascade,
  full_name text not null,
  contact_email text not null,
  notes text,
  annual_fee_yen integer not null default 5000,
  payment_platform text not null default 'google_play',
  status text not null default 'pending',
  admin_note text,
  payment_request_sent_at timestamptz,
  activated_at timestamptz,
  expires_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('pending', 'approved', 'rejected', 'payment_requested', 'active', 'expired')),
  check (annual_fee_yen > 0)
);

create index if not exists idx_ad_free_membership_requests_requester
  on public.ad_free_membership_requests (requester_user_id, created_at desc);

create index if not exists idx_ad_free_membership_requests_status
  on public.ad_free_membership_requests (status, created_at desc);

alter table public.ad_free_membership_requests enable row level security;

drop policy if exists ad_free_membership_requests_select_own on public.ad_free_membership_requests;
create policy ad_free_membership_requests_select_own
  on public.ad_free_membership_requests
  for select
  to authenticated
  using (auth.uid() = requester_user_id or public.is_admin(auth.uid()));

drop policy if exists ad_free_membership_requests_insert_own on public.ad_free_membership_requests;
create policy ad_free_membership_requests_insert_own
  on public.ad_free_membership_requests
  for insert
  to authenticated
  with check (auth.uid() = requester_user_id);

drop policy if exists ad_free_membership_requests_admin_update on public.ad_free_membership_requests;
create policy ad_free_membership_requests_admin_update
  on public.ad_free_membership_requests
  for update
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

drop trigger if exists trg_ad_free_membership_requests_set_updated_at on public.ad_free_membership_requests;
create trigger trg_ad_free_membership_requests_set_updated_at
before update on public.ad_free_membership_requests
for each row execute function public.set_updated_at();
