alter table public.ad_free_membership_requests
  add column if not exists payment_reference text;