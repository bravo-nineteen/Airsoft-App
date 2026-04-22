-- 010_shops.sql
-- Airsoft shops directory for Japan

create table if not exists public.shops (
  id            uuid         primary key default gen_random_uuid(),
  name          text         not null,
  address       text         not null default '',
  prefecture    text,
  city          text,
  opening_times text,
  phone_number  text,
  features      text,
  image_url     text,
  latitude      double precision,
  longitude     double precision,
  is_official   boolean      not null default false,
  created_at    timestamptz  not null default now()
);

alter table public.shops enable row level security;

create policy "shops are publicly readable"
  on public.shops for select using (true);

-- Indexes
create index if not exists shops_prefecture_idx on public.shops (prefecture);
create index if not exists shops_name_idx       on public.shops (name);
