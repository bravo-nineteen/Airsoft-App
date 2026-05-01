-- Migration: location_country_columns
-- Adds strict country storage for events, fields, and shops.

alter table public.events
  add column if not exists country text;

alter table public.fields
  add column if not exists country text;

alter table public.shops
  add column if not exists country text;

update public.events
set country = 'Japan'
where country is null
  and (
    prefecture in (
      'Hokkaido','Aomori','Iwate','Miyagi','Akita','Yamagata','Fukushima',
      'Ibaraki','Tochigi','Gunma','Saitama','Chiba','Tokyo','Kanagawa',
      'Niigata','Toyama','Ishikawa','Fukui','Yamanashi','Nagano','Gifu',
      'Shizuoka','Aichi','Mie','Shiga','Kyoto','Osaka','Hyogo','Nara',
      'Wakayama','Tottori','Shimane','Okayama','Hiroshima','Yamaguchi',
      'Tokushima','Kagawa','Ehime','Kochi','Fukuoka','Saga','Nagasaki',
      'Kumamoto','Oita','Miyazaki','Kagoshima','Okinawa'
    )
    or coalesce(location, '') ilike '%japan%'
    or coalesce(location, '') like '%日本%'
  );

update public.fields
set country = 'Japan'
where country is null
  and (
    prefecture in (
      'Hokkaido','Aomori','Iwate','Miyagi','Akita','Yamagata','Fukushima',
      'Ibaraki','Tochigi','Gunma','Saitama','Chiba','Tokyo','Kanagawa',
      'Niigata','Toyama','Ishikawa','Fukui','Yamanashi','Nagano','Gifu',
      'Shizuoka','Aichi','Mie','Shiga','Kyoto','Osaka','Hyogo','Nara',
      'Wakayama','Tottori','Shimane','Okayama','Hiroshima','Yamaguchi',
      'Tokushima','Kagawa','Ehime','Kochi','Fukuoka','Saga','Nagasaki',
      'Kumamoto','Oita','Miyazaki','Kagoshima','Okinawa'
    )
    or coalesce(location_name, '') ilike '%japan%'
    or coalesce(location_name, '') like '%日本%'
  );

update public.shops
set country = 'Japan'
where country is null
  and (
    prefecture in (
      'Hokkaido','Aomori','Iwate','Miyagi','Akita','Yamagata','Fukushima',
      'Ibaraki','Tochigi','Gunma','Saitama','Chiba','Tokyo','Kanagawa',
      'Niigata','Toyama','Ishikawa','Fukui','Yamanashi','Nagano','Gifu',
      'Shizuoka','Aichi','Mie','Shiga','Kyoto','Osaka','Hyogo','Nara',
      'Wakayama','Tottori','Shimane','Okayama','Hiroshima','Yamaguchi',
      'Tokushima','Kagawa','Ehime','Kochi','Fukuoka','Saga','Nagasaki',
      'Kumamoto','Oita','Miyazaki','Kagoshima','Okinawa'
    )
    or coalesce(address, '') ilike '%japan%'
    or coalesce(address, '') like '%日本%'
  );

create index if not exists idx_events_country on public.events(country);
create index if not exists idx_fields_country on public.fields(country);
create index if not exists idx_shops_country on public.shops(country);