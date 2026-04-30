-- 021_user_submitted_listings.sql
-- Allow authenticated users to submit fields and shops for admin review.
-- New rows from non-admins default to status='pending'; admins get 'approved'.

-- ─── Add columns ────────────────────────────────────────────────────────────

ALTER TABLE public.fields
  ADD COLUMN IF NOT EXISTS status               text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS submitted_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS status               text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS submitted_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ─── Check constraints ───────────────────────────────────────────────────────

ALTER TABLE public.fields
  DROP CONSTRAINT IF EXISTS fields_status_check;
ALTER TABLE public.fields
  ADD CONSTRAINT fields_status_check
  CHECK (status IN ('pending', 'approved', 'rejected'));

ALTER TABLE public.shops
  DROP CONSTRAINT IF EXISTS shops_status_check;
ALTER TABLE public.shops
  ADD CONSTRAINT shops_status_check
  CHECK (status IN ('pending', 'approved', 'rejected'));

-- ─── Trigger: enforce status on INSERT ──────────────────────────────────────
-- Non-admins always get status='pending' and submitted_by_user_id=auth.uid().
-- Admins keep whatever status they set (defaulting to 'approved').

CREATE OR REPLACE FUNCTION public.enforce_listing_submission_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()
  ) THEN
    NEW.status               := 'pending';
    NEW.submitted_by_user_id := auth.uid();
  ELSE
    IF NEW.status IS NULL OR NEW.status NOT IN ('pending', 'approved', 'rejected') THEN
      NEW.status := 'approved';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_fields_submission_status ON public.fields;
CREATE TRIGGER enforce_fields_submission_status
  BEFORE INSERT ON public.fields
  FOR EACH ROW EXECUTE FUNCTION public.enforce_listing_submission_status();

DROP TRIGGER IF EXISTS enforce_shops_submission_status ON public.shops;
CREATE TRIGGER enforce_shops_submission_status
  BEFORE INSERT ON public.shops
  FOR EACH ROW EXECUTE FUNCTION public.enforce_listing_submission_status();

-- ─── RLS: fields ─────────────────────────────────────────────────────────────

-- SELECT: approved rows are public; users can also see their own pending/rejected.
-- Admins can see every row (needed for the pending submissions review tab).
DROP POLICY IF EXISTS "Fields are readable by everyone" ON public.fields;
CREATE POLICY "Fields are readable by everyone"
  ON public.fields FOR SELECT
  TO authenticated, anon
  USING (status = 'approved' OR submitted_by_user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can read all fields" ON public.fields;
CREATE POLICY "Admins can read all fields"
  ON public.fields FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()));

-- INSERT: any authenticated user may submit; trigger enforces status.
DROP POLICY IF EXISTS "Authenticated users can submit fields" ON public.fields;
CREATE POLICY "Authenticated users can submit fields"
  ON public.fields FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- UPDATE / DELETE: admin only.
DROP POLICY IF EXISTS "Admins can update fields" ON public.fields;
CREATE POLICY "Admins can update fields"
  ON public.fields FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins can delete fields" ON public.fields;
CREATE POLICY "Admins can delete fields"
  ON public.fields FOR DELETE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()));

-- ─── RLS: shops ──────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "shops are publicly readable" ON public.shops;
CREATE POLICY "shops are publicly readable"
  ON public.shops FOR SELECT
  TO authenticated, anon
  USING (status = 'approved' OR submitted_by_user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can read all shops" ON public.shops;
CREATE POLICY "Admins can read all shops"
  ON public.shops FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Authenticated users can submit shops" ON public.shops;
CREATE POLICY "Authenticated users can submit shops"
  ON public.shops FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can update shops" ON public.shops;
CREATE POLICY "Admins can update shops"
  ON public.shops FOR UPDATE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins can delete shops" ON public.shops;
CREATE POLICY "Admins can delete shops"
  ON public.shops FOR DELETE
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_roles WHERE user_id = auth.uid()));

-- ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS fields_status_idx        ON public.fields (status);
CREATE INDEX IF NOT EXISTS fields_submitted_by_idx  ON public.fields (submitted_by_user_id);
CREATE INDEX IF NOT EXISTS shops_status_idx         ON public.shops  (status);
CREATE INDEX IF NOT EXISTS shops_submitted_by_idx   ON public.shops  (submitted_by_user_id);
