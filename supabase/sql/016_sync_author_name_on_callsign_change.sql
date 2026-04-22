-- 016_sync_author_name_on_callsign_change.sql
-- When a user updates their call_sign in the profiles table, propagate the
-- new name to every place it was denormalised at write-time.

CREATE OR REPLACE FUNCTION public.sync_author_name_on_callsign_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only act when call_sign actually changed.
  IF NEW.call_sign IS NOT DISTINCT FROM OLD.call_sign THEN
    RETURN NEW;
  END IF;

  -- Community posts
  UPDATE public.community_posts
     SET author_name = NEW.call_sign
   WHERE author_id = NEW.id;

  -- Community comments
  UPDATE public.community_comments
     SET author_name = NEW.call_sign
   WHERE author_id = NEW.id;

  -- Direct messages (display_name column if it exists)
  UPDATE public.direct_messages
     SET sender_name = NEW.call_sign
   WHERE sender_id = NEW.id
     AND EXISTS (
       SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'direct_messages'
          AND column_name  = 'sender_name'
     );

  RETURN NEW;
END;
$$;

-- Attach the trigger to the profiles table.
DROP TRIGGER IF EXISTS trg_sync_author_name ON public.profiles;

CREATE TRIGGER trg_sync_author_name
  AFTER UPDATE OF call_sign ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_author_name_on_callsign_change();
