-- Test the fixed profile image function

-- First, let's see what data we have in pass_movements with processed_by
SELECT 
    pm.id,
    pm.processed_by,
    p.full_name,
    p.profile_image_url,
    pm.movement_type,
    pm.processed_at
FROM pass_movements pm
LEFT JOIN profiles p ON p.id = pm.processed_by
ORDER BY pm.processed_at DESC
LIMIT 5;

-- Test the function with a specific pass ID
-- Replace 'your-pass-id' with an actual pass ID from your database
SELECT * FROM get_pass_movement_history('your-pass-id');

-- Check if we have any profile images in the profiles table
SELECT 
    id,
    full_name,
    profile_image_url
FROM profiles 
WHERE profile_image_url IS NOT NULL
LIMIT 5;