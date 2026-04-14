create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  new_event boolean not null default true,
  meetup_activity boolean not null default true,
  direct_message boolean not null default true,
  field_updates boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;
alter table public.device_tokens enable row level security;

drop policy if exists "Users can read own notification preferences" on public.notification_preferences;
create policy "Users can read own notification preferences"
on public.notification_preferences
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can upsert own notification preferences" on public.notification_preferences;
create policy "Users can upsert own notification preferences"
on public.notification_preferences
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can manage own device tokens" on public.device_tokens;
create policy "Users can manage own device tokens"
on public.device_tokens
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
