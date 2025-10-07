-- Test the movement history function directly

-- Test the function with a sample pass ID to see what it returns
-- Replace 'your-pass-id-here' with an actual pass ID from your database

-- First, let's see what pass IDs exist
SELECT id, short_code FROM purchased_passes LIMIT 5;

-- Then test the function (replace the UUID with a real one from above)
-- SELECT * FROM get_pass_movement_history('45387c90-c8f9-4f2a-b1c0-cede06bcea1a');

-- Also check what your current profile image URL is
SELECT 
    id,
    full_name,
    email,
    profile_image_url,
    CASE 
        WHEN profile_image_url IS NULL THEN 'NULL - No image URL'
        WHEN profile_image_url = '' THEN 'EMPTY - Empty string'
        ELSE 'HAS URL - ' || profile_image_url
    END as url_status
FROM profiles 
WHERE id = auth.uid();