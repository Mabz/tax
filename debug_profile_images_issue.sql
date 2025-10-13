-- Debug profile images issue in manage users

-- 1. Check if the function was updated to include profile_image_url
SELECT 
    'Function definition check' as test,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'get_authority_profiles_for_admin';

-- 2. Check if users have profile images in the profiles table
SELECT 
    'Profile images check' as test,
    p.id,
    p.email,
    p.full_name,
    p.profile_image_url,
    CASE 
        WHEN p.profile_image_url IS NULL THEN 'No image'
        WHEN p.profile_image_url = '' THEN 'Empty string'
        ELSE 'Has image URL'
    END as image_status
FROM profiles p
WHERE p.id IN (
    SELECT DISTINCT ap.profile_id 
    FROM authority_profiles ap
    LIMIT 5
);

-- 3. Test the function directly to see what it returns
-- Replace with your actual authority ID
SELECT 
    'Function test' as test,
    'Replace with actual authority ID and run manually' as instruction;

-- Example (replace with real authority ID):
-- SELECT 
--     id,
--     profile_email,
--     profile_image_url
-- FROM get_authority_profiles_for_admin('your-authority-id-here')
-- LIMIT 3;

-- 4. Check if authority_profiles exist and get sample authority ID
SELECT 
    'Sample authority ID' as test,
    authority_id,
    COUNT(*) as profile_count
FROM authority_profiles
GROUP BY authority_id
LIMIT 3;

-- 5. Check the profiles table structure
SELECT 
    'Profiles table columns' as test,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name LIKE '%image%';

-- 6. Check if any profiles have images at all
SELECT 
    'Profiles with images count' as test,
    COUNT(*) as total_profiles,
    COUNT(profile_image_url) as profiles_with_image_url,
    COUNT(CASE WHEN profile_image_url IS NOT NULL AND profile_image_url != '' THEN 1 END) as profiles_with_actual_images
FROM profiles;