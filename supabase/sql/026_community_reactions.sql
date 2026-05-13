-- 026_community_reactions.sql
-- Add reaction types for community post/comment likes.

alter table public.community_post_likes
  add column if not exists reaction text not null default 'thumbs_up';

alter table public.community_comment_likes
  add column if not exists reaction text not null default 'thumbs_up';

update public.community_post_likes
set reaction = 'thumbs_up'
where reaction is null or btrim(reaction) = '';

update public.community_comment_likes
set reaction = 'thumbs_up'
where reaction is null or btrim(reaction) = '';

alter table public.community_post_likes
  drop constraint if exists community_post_likes_reaction_check;
alter table public.community_post_likes
  add constraint community_post_likes_reaction_check
  check (reaction in ('thumbs_up', 'thumbs_down', 'confused', 'angry', 'sad', 'love'));

alter table public.community_comment_likes
  drop constraint if exists community_comment_likes_reaction_check;
alter table public.community_comment_likes
  add constraint community_comment_likes_reaction_check
  check (reaction in ('thumbs_up', 'thumbs_down', 'confused', 'angry', 'sad', 'love'));

create index if not exists idx_community_post_likes_reaction
  on public.community_post_likes (reaction);

create index if not exists idx_community_comment_likes_reaction
  on public.community_comment_likes (reaction);
