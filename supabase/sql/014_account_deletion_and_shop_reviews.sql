-- 014_account_deletion.sql
-- Provides a secure function users can call to delete their own account data.
-- The function runs with SECURITY DEFINER so it can bypass RLS to delete
-- all rows belonging to the calling user, then removes the auth user.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete social data
  DELETE FROM public.direct_messages
    WHERE sender_id = _uid OR recipient_id = _uid;
  DELETE FROM public.user_contacts
    WHERE requester_id = _uid OR addressee_id = _uid;
  DELETE FROM public.notifications
    WHERE user_id = _uid OR actor_user_id = _uid;

  -- Delete community content
  DELETE FROM public.community_comments WHERE author_id = _uid;
  DELETE FROM public.community_posts   WHERE author_id = _uid;

  -- Delete event attendance
  DELETE FROM public.event_attendees WHERE user_id = _uid;
  DELETE FROM public.event_checkins  WHERE attendee_user_id = _uid;
  DELETE FROM public.event_comments  WHERE user_id = _uid;

  -- Delete field/shop reviews
  DELETE FROM public.field_reviews WHERE user_id = _uid;
  DELETE FROM public.shop_reviews  WHERE user_id = _uid;

  -- Delete push tokens
  DELETE FROM public.push_tokens WHERE user_id = _uid;

  -- Delete bans issued by / against this user
  DELETE FROM public.user_bans WHERE user_id = _uid;

  -- Delete the profile last
  DELETE FROM public.profiles WHERE id = _uid;

  -- Remove the auth user (requires pg_net / service-role inside function)
  -- This call succeeds when the Supabase project has the required extension.
  BEGIN
    PERFORM extensions.http_delete(
      url := 'https://' || current_setting('app.supabase_url', true)
             || '/auth/v1/admin/users/' || _uid::text,
      headers := jsonb_build_object(
        'apikey', current_setting('app.service_role_key', true),
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- If http extension or settings are unavailable the RPC still succeeds;
    -- the orphan auth user will be cleaned up by the admin panel.
    NULL;
  END;
END;
$$;

-- Grant execute to authenticated users only.
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.delete_my_account() FROM anon;

-- ── shop_reviews table (also included here) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shop_reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating      smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, user_id)
);

ALTER TABLE public.shop_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "shop_reviews_select" ON public.shop_reviews;
DROP POLICY IF EXISTS "shop_reviews_insert" ON public.shop_reviews;
DROP POLICY IF EXISTS "shop_reviews_update" ON public.shop_reviews;
DROP POLICY IF EXISTS "shop_reviews_delete" ON public.shop_reviews;

CREATE POLICY "shop_reviews_select" ON public.shop_reviews
  FOR SELECT USING (true);

CREATE POLICY "shop_reviews_insert" ON public.shop_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "shop_reviews_update" ON public.shop_reviews
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "shop_reviews_delete" ON public.shop_reviews
  FOR DELETE USING (auth.uid() = user_id);

-- ── field_photos table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.field_photos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id     uuid NOT NULL REFERENCES public.fields(id) ON DELETE CASCADE,
  photo_url    text NOT NULL,
  uploaded_by  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Add uploaded_by column if it doesn't exist yet (table may have been created without it).
ALTER TABLE public.field_photos
  ADD COLUMN IF NOT EXISTS uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.field_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "field_photos_select" ON public.field_photos;
DROP POLICY IF EXISTS "field_photos_insert" ON public.field_photos;
DROP POLICY IF EXISTS "field_photos_delete" ON public.field_photos;

CREATE POLICY "field_photos_select" ON public.field_photos
  FOR SELECT USING (true);

CREATE POLICY "field_photos_insert" ON public.field_photos
  FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

CREATE POLICY "field_photos_delete" ON public.field_photos
  FOR DELETE USING (auth.uid() = uploaded_by);
