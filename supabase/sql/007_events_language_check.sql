-- Normalize event language values and enforce a consistent check constraint.
-- Prevents 23514 errors when clients submit mixed-case values.

alter table public.events
  drop constraint if exists events_language_check;

update public.events
set language = case
  when language is null then null
  when lower(trim(language)) in ('english', 'japanese', 'bilingual') then lower(trim(language))
  else 'bilingual'
end;

alter table public.events
  add constraint events_language_check
  check (language is null or language in ('english', 'japanese', 'bilingual'));
