-- 027_reactions_expansion.sql
-- Expand reactions beyond community boards: event comments + direct messages.

create table if not exists public.event_comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.event_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

create index if not exists idx_event_comment_reactions_comment_id
  on public.event_comment_reactions (comment_id);

create index if not exists idx_event_comment_reactions_user_id
  on public.event_comment_reactions (user_id);

create index if not exists idx_event_comment_reactions_reaction
  on public.event_comment_reactions (reaction);

alter table public.event_comment_reactions
  drop constraint if exists event_comment_reactions_reaction_check;
alter table public.event_comment_reactions
  add constraint event_comment_reactions_reaction_check
  check (reaction in ('thumbs_up', 'thumbs_down', 'confused', 'angry', 'sad', 'love'));

alter table public.event_comment_reactions enable row level security;

drop policy if exists event_comment_reactions_select_public on public.event_comment_reactions;
create policy event_comment_reactions_select_public
  on public.event_comment_reactions
  for select
  using (true);

drop policy if exists event_comment_reactions_manage_own on public.event_comment_reactions;
create policy event_comment_reactions_manage_own
  on public.event_comment_reactions
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Normalize existing DM reactions to the same set and one reaction per user/message.
update public.direct_message_reactions
set reaction = 'thumbs_up'
where reaction is null
   or btrim(reaction) = ''
   or reaction not in ('thumbs_up', 'thumbs_down', 'confused', 'angry', 'sad', 'love');

-- Keep latest reaction per (message_id, user_id) before tightening uniqueness.
with ranked as (
  select
    id,
    row_number() over (
      partition by message_id, user_id
      order by created_at desc, id desc
    ) as rn
  from public.direct_message_reactions
)
delete from public.direct_message_reactions d
using ranked r
where d.id = r.id
  and r.rn > 1;

alter table public.direct_message_reactions
  drop constraint if exists direct_message_reactions_reaction_check;
alter table public.direct_message_reactions
  add constraint direct_message_reactions_reaction_check
  check (reaction in ('thumbs_up', 'thumbs_down', 'confused', 'angry', 'sad', 'love'));

alter table public.direct_message_reactions
  drop constraint if exists direct_message_reactions_message_id_user_id_reaction_key;
alter table public.direct_message_reactions
  drop constraint if exists direct_message_reactions_message_id_user_id_key;
alter table public.direct_message_reactions
  add constraint direct_message_reactions_message_id_user_id_key
  unique (message_id, user_id);
