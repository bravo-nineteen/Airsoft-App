-- 018_storage_buckets.sql
-- Ensure Supabase Storage buckets for community post images and avatars
-- have the correct public access settings and RLS policies.
-- Safe to run multiple times (all statements are idempotent).

-- ── community-images bucket ───────────────────────────────────────────────────
-- Upsert the bucket so it exists and is public.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'community-images',
  'community-images',
  true,
  10485760,  -- 10 MB per file
  ARRAY['image/jpeg','image/jpg','image/png','image/webp','image/gif']
)
ON CONFLICT (id) DO UPDATE
  SET public            = true,
      file_size_limit   = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read: anyone can see images in this bucket.
DROP POLICY IF EXISTS "community_images_public_read" ON storage.objects;
CREATE POLICY "community_images_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'community-images');

-- Authenticated upload: users can only upload into their own sub-folder.
-- Path format: community/{user_id}/{filename}
DROP POLICY IF EXISTS "community_images_auth_insert" ON storage.objects;
CREATE POLICY "community_images_auth_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'community-images'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Owners can update (e.g. replace) their own files.
DROP POLICY IF EXISTS "community_images_auth_update" ON storage.objects;
CREATE POLICY "community_images_auth_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'community-images'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Owners can delete their own files.
DROP POLICY IF EXISTS "community_images_auth_delete" ON storage.objects;
CREATE POLICY "community_images_auth_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'community-images'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- ── avatars bucket ────────────────────────────────────────────────────────────
-- Avatars are also public; this is idempotent in case the bucket was created
-- manually without public=true or without RLS policies.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880,  -- 5 MB per file
  ARRAY['image/jpeg','image/jpg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public            = true,
      file_size_limit   = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_auth_insert" ON storage.objects;
CREATE POLICY "avatars_auth_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_auth_update" ON storage.objects;
CREATE POLICY "avatars_auth_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_auth_delete" ON storage.objects;
CREATE POLICY "avatars_auth_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
