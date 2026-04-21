-- Add optional image support for community comments.

alter table public.community_comments
  add column if not exists image_url text;
