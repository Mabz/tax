-- Check if you have a profile image URL in your database

-- Check your current profile data
SELECT 
    id,
    full_name,
    email,
    profile_image_url,
    CASE 
        WHEN profile_image_url IS NULL THEN '❌ NULL - No image URL set'
        WHEN profile_image_url = '' THEN '⚠️ EMPTY - Empty string'
        WHEN profile_image_url LIKE 'http%' THEN '✅ HAS URL - Valid URL format'
        ELSE '⚠️ UNKNOWN - ' || profile_image_url
    END as url_status
FROM profiles 
WHERE id = auth.uid();

-- Also check if auth.uid() is working
SELECT 
    auth.uid() as current_user_id,
    CASE 
        WHEN auth.uid() IS NULL THEN '❌ Not authenticated'
        ELSE '✅ Authenticated'
    END as auth_status;