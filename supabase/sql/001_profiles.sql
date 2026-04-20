create extension if not exists pgcrypto;

create or replace function public.generate_user_code(user_id uuid)
returns text
language sql
immutable
as $$
  select 'AOJ-' || upper(substr(replace(user_id::text, '-', ''), 1, 8));
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  user_code text unique not null,
  call_sign text not null,
  area text,
  team_name text,
  loadout text,
  loadout_cards jsonb not null default '[]'::jsonb,
  instagram text,
  facebook text,
  youtube text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  if to_jsonb(new) ? 'updated_at' then
    new := jsonb_populate_record(
      new,
      jsonb_set(to_jsonb(new), '{updated_at}', to_jsonb(now()))
    );
  end if;
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    user_code,
    call_sign
  )
  values (
    new.id,
    public.generate_user_code(new.id),
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'call_sign'), ''),
      'Operator'
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
