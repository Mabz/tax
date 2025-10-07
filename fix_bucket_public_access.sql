-- Fix bucket public access for profile images

-- Update the bucket to ensure it's properly public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'BorderTax';

-- Drop and recreate policies to ensure they work correctly
DROP POLICY IF EXISTS "profile_images_insert" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_select" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_update" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_delete" ON storage.objects;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create a simple public read policy for all objects in BorderTax bucket
CREATE POLICY "BorderTax_public_read" ON storage.objects
FOR SELECT USING (bucket_id = 'BorderTax');

-- Create insert policy for authenticated users
CREATE POLICY "BorderTax_authenticated_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
);

-- Create update policy for file owners
CREATE POLICY "BorderTax_owner_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/%'
);

-- Create delete policy for file owners
CREATE POLICY "BorderTax_owner_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/%'
);

-- Verify the bucket is public
SELECT id, name, public FROM storage.buckets WHERE id = 'BorderTax';

-- Check policies
SELECT policyname, cmd FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE 'BorderTax%';