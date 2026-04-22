-- 015_community_posts_language_check.sql
-- Fixes 23514 check constraint violation when posting with images.
-- The existing community_posts_language_check only allowed ('english','japanese').
-- The app also produces 'bilingual' and 'all', so we widen the constraint.

-- Normalize any out-of-range values that already exist in the table.
UPDATE public.community_posts
SET language = CASE
  WHEN language IS NULL                                   THEN 'english'
  WHEN lower(trim(language)) IN ('en', 'english')        THEN 'english'
  WHEN lower(trim(language)) IN ('ja', 'jp', 'japanese') THEN 'japanese'
  WHEN lower(trim(language)) IN ('bi', 'bilingual',
       'english / japanese', 'japanese / english')       THEN 'bilingual'
  WHEN lower(trim(language)) = 'all'                     THEN 'all'
  ELSE 'english'
END
WHERE language NOT IN ('english', 'japanese', 'bilingual', 'all');

-- Drop and recreate the constraint to include all values the app sends.
ALTER TABLE public.community_posts
  DROP CONSTRAINT IF EXISTS community_posts_language_check;

ALTER TABLE public.community_posts
  ADD CONSTRAINT community_posts_language_check
  CHECK (language IN ('english', 'japanese', 'bilingual', 'all'));
