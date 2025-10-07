-- Fix storage RLS policies for profile images

-- First, drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;

-- Create the BorderTax storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('BorderTax', 'BorderTax', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create policy for users to upload their own profile images
CREATE POLICY "Users can upload their own profile images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'BorderTax' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND (storage.foldername(name))[2] LIKE 'profile_image_%'
);

-- Create policy for users to view all profile images (read access)
CREATE POLICY "Anyone can view profile images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'BorderTax'
  AND (storage.foldername(name))[2] LIKE 'profile_image_%'
);

-- Create policy for users to update their own profile images
CREATE POLICY "Users can update their own profile images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND (storage.foldername(name))[2] LIKE 'profile_image_%'
);

-- Create policy for users to delete their own profile images
CREATE POLICY "Users can delete their own profile images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND (storage.foldername(name))[2] LIKE 'profile_image_%'
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

-- Verify the setup
SELECT 
    'Bucket created' as status,
    id,
    name,
    public
FROM storage.buckets 
WHERE id = 'BorderTax';

SELECT 
    'Policies created' as status,
    policyname,
    cmd,
    permissive
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%profile images%';