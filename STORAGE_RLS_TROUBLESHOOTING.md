# Storage RLS Policy Troubleshooting

## Error: "Failed to up new row violates row level security policy"

This error occurs when trying to upload files to Supabase Storage without proper RLS policies set up.

## Quick Fix

### Step 1: Run the SQL Setup
Execute one of these SQL scripts in your Supabase SQL Editor:

**Option 1: Simple Setup (Recommended)**
```sql
-- Run the contents of simple_storage_setup.sql
```

**Option 2: Advanced Setup**
```sql
-- Run the contents of fix_storage_rls_policies.sql
```

### Step 2: Verify Setup
Check that the bucket and policies were created:

```sql
-- Check bucket exists
SELECT * FROM storage.buckets WHERE id = 'BorderTax';

-- Check policies exist
SELECT policyname, cmd FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';
```

## Manual Setup (Alternative)

If the SQL scripts don't work, you can set up manually:

### 1. Create Storage Bucket
In Supabase Dashboard:
1. Go to Storage
2. Create new bucket named "BorderTax"
3. Make it public
4. Enable RLS

### 2. Create Policies
Add these policies to the `storage.objects` table:

**Insert Policy:**
```sql
CREATE POLICY "Users can upload profile images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/profile_image_%'
);
```

**Select Policy:**
```sql
CREATE POLICY "Anyone can view profile images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'BorderTax'
  AND name LIKE '%/profile_image_%'
);
```

**Update Policy:**
```sql
CREATE POLICY "Users can update profile images" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/profile_image_%'
);
```

**Delete Policy:**
```sql
CREATE POLICY "Users can delete profile images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'BorderTax' 
  AND auth.uid() IS NOT NULL
  AND name LIKE auth.uid()::text || '/profile_image_%'
);
```

### 3. Add Database Column
```sql
ALTER TABLE profiles ADD COLUMN profile_image_url TEXT;
```

## Testing the Setup

After running the setup, test with this query:
```sql
-- This should return your bucket
SELECT * FROM storage.buckets WHERE id = 'BorderTax';

-- This should return 4 policies
SELECT COUNT(*) FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%profile%';
```

## Common Issues

### Issue 1: Bucket Already Exists
If you get "bucket already exists" error, that's fine - the bucket is there.

### Issue 2: Policy Already Exists
If you get "policy already exists" error, drop the existing policies first:
```sql
DROP POLICY IF EXISTS "policy_name" ON storage.objects;
```

### Issue 3: RLS Not Enabled
Enable RLS on storage.objects:
```sql
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
```

### Issue 4: Authentication Issues
Make sure you're logged in when testing uploads. The policies require `auth.uid()` to be present.

## File Structure Expected

The policies expect files to be stored as:
```
BorderTax/
  ├── {user_id}/
  │   ├── profile_image_1234567890.jpg
  │   ├── profile_image_1234567891.png
  │   └── ...
  └── {another_user_id}/
      ├── profile_image_1234567892.jpg
      └── ...
```

## Status Check

After setup, you should be able to:
- ✅ Upload images to your own folder
- ✅ View any profile image
- ✅ Update/delete only your own images
- ❌ Upload to other users' folders
- ❌ Delete other users' images

## Next Steps

1. **Run the SQL setup** using one of the provided scripts
2. **Test the upload** in your Flutter app
3. **Check the Storage tab** in Supabase to see uploaded files
4. **Verify permissions** by trying to access files from different users