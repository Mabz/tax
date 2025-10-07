-- Test query to verify profile relationship and data structure
-- This will help us understand if the JOIN is working correctly

-- First, let's check if we have any purchased_passes with profile_id
SELECT 
    COUNT(*) as total_passes,
    COUNT(profile_id) as passes_with_profile_id,
    COUNT(DISTINCT profile_id) as unique_profiles
FROM purchased_passes;

-- Check the structure of profiles table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- Test the JOIN query (limit to 5 records)
SELECT 
    pp.id as pass_id,
    pp.profile_id,
    pp.vehicle_description,
    pp.expires_at,
    pp.current_status,
    p.full_name,
    p.email,
    p.phone_number,
    p.company_name
FROM purchased_passes pp
LEFT JOIN profiles p ON pp.profile_id = p.id
WHERE pp.current_status = 'checked_in' 
  AND pp.expires_at < NOW()
LIMIT 5;

-- Check if there are any overstayed vehicles with profile data
SELECT 
    COUNT(*) as overstayed_count,
    COUNT(p.id) as with_profile_data
FROM purchased_passes pp
LEFT JOIN profiles p ON pp.profile_id = p.id
WHERE pp.current_status = 'checked_in' 
  AND pp.expires_at < NOW();