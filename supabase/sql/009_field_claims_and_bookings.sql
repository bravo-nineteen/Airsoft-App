-- Field ownership claims and booking system.

alter table public.fields
  add column if not exists claim_status text not null default 'unclaimed';
alter table public.fields
  add column if not exists claimed_by_user_id uuid references public.profiles(id) on delete set null;
alter table public.fields
  add column if not exists claim_verified_at timestamptz;
alter table public.fields
  add column if not exists booking_enabled boolean not null default false;
alter table public.fields
  add column if not exists booking_contact_name text;
alter table public.fields
  add column if not exists booking_phone text;
alter table public.fields
  add column if not exists booking_email text;

-- Backfill columns introduced in app code after initial social/events schema.
alter table public.direct_messages
  add column if not exists image_url text;
alter table public.direct_messages
  add column if not exists expires_at timestamptz;
alter table public.direct_messages
  add column if not exists unsent_at timestamptz;
alter table public.events
  add column if not exists pinned_until timestamptz;
alter table public.events
  add column if not exists image_uploaded_at timestamptz;
alter table public.events
  add column if not exists book_tickets_url text;

create index if not exists idx_direct_messages_expires_at
  on public.direct_messages (expires_at)
  where expires_at is not null;

-- Backfill missing image upload timestamps for existing event images.
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

alter table public.fields
  drop constraint if exists fields_claim_status_check;
alter table public.fields
  add constraint fields_claim_status_check
  check (claim_status in ('unclaimed', 'pending', 'verified'));

create table if not exists public.field_claim_requests (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  requester_user_id uuid not null references public.profiles(id) on delete cascade,
  staff_name text not null,
  official_id_number text not null,
  official_phone text not null,
  official_email text not null,
  verification_note text,
  payment_amount_yen integer not null default 5000,
  payment_platform text not null default 'google_play',
  payment_reference text,
  payment_status text not null default 'pending',
  verification_status text not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (payment_status in ('pending', 'paid', 'refunded')),
  check (verification_status in ('pending', 'approved', 'rejected'))
);

create index if not exists idx_field_claim_requests_field_id
  on public.field_claim_requests (field_id);
create index if not exists idx_field_claim_requests_requester
  on public.field_claim_requests (requester_user_id);
create index if not exists idx_field_claim_requests_status
  on public.field_claim_requests (verification_status, payment_status);

create table if not exists public.field_booking_options (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  option_type text not null default 'other',
  label text not null,
  price_yen integer,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (option_type in ('pickup', 'lunch', 'other'))
);

create index if not exists idx_field_booking_options_field_id
  on public.field_booking_options (field_id, is_active, sort_order);

create table if not exists public.field_bookings (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  booking_name text not null,
  booking_phone text not null,
  booking_email text not null,
  message text not null,
  selected_options jsonb not null default '[]'::jsonb,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('pending', 'confirmed', 'cancelled'))
);

create index if not exists idx_field_bookings_field_id
  on public.field_bookings (field_id, created_at desc);
create index if not exists idx_field_bookings_user_id
  on public.field_bookings (user_id, created_at desc);
create index if not exists idx_field_bookings_status
  on public.field_bookings (status, created_at desc);

alter table public.field_claim_requests enable row level security;
alter table public.field_booking_options enable row level security;
alter table public.field_bookings enable row level security;

-- Claims: requester can create/read own requests. Admin can fully manage.
drop policy if exists field_claim_requests_select_owner on public.field_claim_requests;
create policy field_claim_requests_select_owner
  on public.field_claim_requests
  for select
  to authenticated
  using (auth.uid() = requester_user_id or public.is_admin(auth.uid()));

drop policy if exists field_claim_requests_insert_owner on public.field_claim_requests;
create policy field_claim_requests_insert_owner
  on public.field_claim_requests
  for insert
  to authenticated
  with check (auth.uid() = requester_user_id);

drop policy if exists field_claim_requests_admin_update on public.field_claim_requests;
create policy field_claim_requests_admin_update
  on public.field_claim_requests
  for update
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- Field owners + admins can update their field listing.
drop policy if exists fields_owner_update_verified on public.fields;
create policy fields_owner_update_verified
  on public.fields
  for update
  to authenticated
  using (public.is_admin(auth.uid()) or claimed_by_user_id = auth.uid())
  with check (public.is_admin(auth.uid()) or claimed_by_user_id = auth.uid());

-- Booking options are public to read and managed by verified field owner/admin.
drop policy if exists field_booking_options_select_public on public.field_booking_options;
create policy field_booking_options_select_public
  on public.field_booking_options
  for select
  to authenticated, anon
  using (is_active = true);

drop policy if exists field_booking_options_owner_insert on public.field_booking_options;
create policy field_booking_options_owner_insert
  on public.field_booking_options
  for insert
  to authenticated
  with check (
    public.is_admin(auth.uid())
    or exists (
      select 1
      from public.fields f
      where f.id = field_id
        and f.claimed_by_user_id = auth.uid()
        and f.claim_status = 'verified'
    )
  );

drop policy if exists field_booking_options_owner_update on public.field_booking_options;
create policy field_booking_options_owner_update
  on public.field_booking_options
  for update
  to authenticated
  using (
    public.is_admin(auth.uid())
    or exists (
      select 1
      from public.fields f
      where f.id = field_id
        and f.claimed_by_user_id = auth.uid()
        and f.claim_status = 'verified'
    )
  )
  with check (
    public.is_admin(auth.uid())
    or exists (
      select 1
      from public.fields f
      where f.id = field_id
        and f.claimed_by_user_id = auth.uid()
        and f.claim_status = 'verified'
    )
  );

-- Bookings: any auth user can request, owner/admin can read/manage.
drop policy if exists field_bookings_insert_authenticated on public.field_bookings;
create policy field_bookings_insert_authenticated
  on public.field_bookings
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists field_bookings_select_participant_owner_admin on public.field_bookings;
create policy field_bookings_select_participant_owner_admin
  on public.field_bookings
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or public.is_admin(auth.uid())
    or exists (
      select 1
      from public.fields f
      where f.id = field_id
        and f.claimed_by_user_id = auth.uid()
        and f.claim_status = 'verified'
    )
  );

drop policy if exists field_bookings_update_owner_admin on public.field_bookings;
create policy field_bookings_update_owner_admin
  on public.field_bookings
  for update
  to authenticated
  using (
    public.is_admin(auth.uid())
    or exists (
      select 1
      from public.fields f
      where f.id = field_id
        and f.claimed_by_user_id = auth.uid()
        and f.claim_status = 'verified'
    )
  )
  with check (
    public.is_admin(auth.uid())
    or exists (
      select 1
      from public.fields f
      where f.id = field_id
        and f.claimed_by_user_id = auth.uid()
        and f.claim_status = 'verified'
    )
  );

-- Direct messages: sender/recipient can update or delete (unsend/delete flows).
drop policy if exists direct_messages_update_recipient on public.direct_messages;
drop policy if exists direct_messages_update_participant on public.direct_messages;
create policy direct_messages_update_participant
  on public.direct_messages
  for update
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = recipient_id)
  with check (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists direct_messages_delete_participant on public.direct_messages;
create policy direct_messages_delete_participant
  on public.direct_messages
  for delete
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = recipient_id);

-- Storage policies for DM/community image uploads by authenticated users.
insert into storage.buckets (id, name, public)
values ('community-images', 'community-images', true)
on conflict (id) do nothing;

drop policy if exists community_images_public_read on storage.objects;
create policy community_images_public_read
  on storage.objects
  for select
  using (bucket_id = 'community-images');

drop policy if exists community_images_auth_insert_own on storage.objects;
create policy community_images_auth_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'community-images'
    and split_part(name, '/', 2) = auth.uid()::text
  );

drop policy if exists community_images_auth_update_own on storage.objects;
create policy community_images_auth_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'community-images'
    and split_part(name, '/', 2) = auth.uid()::text
  )
  with check (
    bucket_id = 'community-images'
    and split_part(name, '/', 2) = auth.uid()::text
  );

drop policy if exists community_images_auth_delete_own on storage.objects;
create policy community_images_auth_delete_own
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'community-images'
    and split_part(name, '/', 2) = auth.uid()::text
  );

-- Keep timestamps in sync.
drop trigger if exists trg_field_claim_requests_set_updated_at on public.field_claim_requests;
create trigger trg_field_claim_requests_set_updated_at
before update on public.field_claim_requests
for each row execute function public.set_updated_at();

drop trigger if exists trg_field_booking_options_set_updated_at on public.field_booking_options;
create trigger trg_field_booking_options_set_updated_at
before update on public.field_booking_options
for each row execute function public.set_updated_at();

drop trigger if exists trg_field_bookings_set_updated_at on public.field_bookings;
create trigger trg_field_bookings_set_updated_at
before update on public.field_bookings
for each row execute function public.set_updated_at();
