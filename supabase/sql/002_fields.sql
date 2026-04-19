create table if not exists public.fields (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location_name text not null,
  prefecture text,
  city text,
  latitude double precision,
  longitude double precision,
  field_type text,
  description text,
  feature_list text,
  pros_list text,
  cons_list text,
  phone text,
  email text,
  website text,
  instagram text,
  facebook text,
  x text,
  youtube text,
  image_url text,
  is_claimed boolean not null default false,
  owner_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.field_reviews (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review_text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (field_id, user_id)
);

alter table public.fields enable row level security;
alter table public.field_reviews enable row level security;

drop policy if exists "Fields are readable by everyone" on public.fields;
create policy "Fields are readable by everyone"
on public.fields
for select
to authenticated, anon
using (true);

drop policy if exists "Field reviews readable by everyone" on public.field_reviews;
create policy "Field reviews readable by everyone"
on public.field_reviews
for select
to authenticated, anon
using (true);

drop policy if exists "Users can manage own field reviews" on public.field_reviews;
create policy "Users can manage own field reviews"
on public.field_reviews
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.set_fields_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_fields_updated_at on public.fields;
create trigger set_fields_updated_at
before update on public.fields
for each row
execute function public.set_fields_updated_at();
