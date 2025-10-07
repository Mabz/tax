# Fix Bucket Public Access - HTTP 400 Error

## Issue Identified
- ✅ Image uploads successfully
- ✅ URL is generated correctly
- ❌ HTTP 400 error when loading image
- **Root Cause**: Bucket public access or RLS policy issue

## Quick Fix Options

### Option 1: SQL Fix (Recommended)
Run this SQL in Supabase SQL Editor:

```sql
-- Fix bucket public access
UPDATE storage.buckets 
SET public = true 
WHERE id = 'BorderTax';

-- Simple public read policy
DROP POLICY IF EXISTS "BorderTax_public_read" ON storage.objects;
CREATE POLICY "BorderTax_public_read" ON storage.objects
FOR SELECT USING (bucket_id = 'BorderTax');
```

### Option 2: Dashboard Fix
1. Go to Supabase Dashboard → Storage
2. Find the "BorderTax" bucket
3. Click the settings/options menu
4. Ensure "Public bucket" is enabled
5. Check RLS policies allow SELECT for everyone

### Option 3: Test URL Fix
Try accessing the image URL directly in your browser:
```
https://cydtpwbgzilgrpozvesv.supabase.co/storage/v1/object/public/BorderTax/cbf0f0a4-2d6d-4496-b944-f69c39aeecc2/profile_image_1759870571131.jpg
```

If it shows a 400 error in browser too, it's definitely a bucket configuration issue.

## Complete Fix Script

Run the complete fix script: `fix_bucket_public_access.sql`

This will:
- ✅ Ensure bucket is public
- ✅ Create simple, working RLS policies
- ✅ Allow public read access to all images
- ✅ Maintain security for uploads/deletes

## Test After Fix

1. **Run the SQL fix**
2. **Try the image URL in browser** - should work
3. **Upload a new profile image** - should display immediately
4. **Check debug logs** - should show successful load

## Expected Result

After the fix:
```
I/flutter: Profile image loaded successfully: https://...
```

Instead of:
```
I/flutter: Error loading profile image: HTTP request failed, statusCode: 400
```

## Alternative: Temporary Public Bucket

If RLS policies are causing issues, you can temporarily make the entire bucket fully public:

```sql
-- Make bucket completely public (temporary solution)
UPDATE storage.buckets 
SET public = true, file_size_limit = 52428800, allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
WHERE id = 'BorderTax';

-- Remove all RLS policies temporarily
DROP POLICY IF EXISTS "BorderTax_public_read" ON storage.objects;
DROP POLICY IF EXISTS "BorderTax_authenticated_insert" ON storage.objects;
DROP POLICY IF EXISTS "BorderTax_owner_update" ON storage.objects;
DROP POLICY IF EXISTS "BorderTax_owner_delete" ON storage.objects;
```

This will make all images in the bucket publicly accessible without any restrictions.

## Status Check

After applying the fix, the image should:
- ✅ Upload successfully (already working)
- ✅ Generate correct URL (already working)  
- ✅ Load in browser when URL is accessed directly
- ✅ Display in the Flutter app immediately after upload

The HTTP 400 error should be completely resolved.