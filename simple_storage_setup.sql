-- Simple storage setup for profile images

-- Create the BorderTax storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('BorderTax', 'BorderTax', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "profile_images_insert" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_select" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_update" ON storage.objects;
DROP POLICY IF EXISTS "profile_images_delete" ON storage.objects;

-- Simple policy for users to manage their own profile images
CREATE POLICY "profile_images_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/profile_image_%'
);

-- Policy for anyone to view profile images
CREATE POLICY "profile_images_select" ON storage.objects
FOR SELECT USING (
  bucket_id = 'BorderTax'
  AND name LIKE '%/profile_image_%'
);

-- Policy for users to update their own profile images
CREATE POLICY "profile_images_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/profile_image_%'
);

-- Policy for users to delete their own profile images
CREATE POLICY "profile_images_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/profile_image_%'
);

-- Add profile_image_url column to profiles table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'profile_image_url'
    ) THEN
        ALTER TABLE profiles ADD COLUMN profile_image_url TEXT;
    END IF;
END $$;