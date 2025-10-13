-- Debug the save functionality issue step by step

-- 1. Check if the update function was actually updated
SELECT 
    'Function definition check' as debug_step,
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'update_authority_profile';

-- 2. Check if you have any authority_profiles to update
SELECT 
    'Available authority profiles' as debug_step,
    ap.id,
    ap.display_name,
    ap.is_active,
    ap.notes,
    a.name as authority_name
FROM authority_profiles ap
JOIN authorities a ON ap.authority_id = a.id
WHERE ap.authority_id IN (
    SELECT pr.authority_id 
    FROM profile_roles pr
    JOIN roles r ON pr.role_id = r.id
    WHERE pr.profile_id = auth.uid()
    AND r.name = 'country_administrator'
    AND pr.is_active = true
)
LIMIT 3;

-- 3. Test your admin role check
SELECT 
    'Admin role check' as debug_step,
    EXISTS (
        SELECT 1 
        FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) as has_admin_role;

-- 4. Test the is_superuser function
SELECT 
    'Superuser check' as debug_step,
    is_superuser() as is_superuser_result;

-- 5. Test the update function directly with a sample ID
-- First get a sample ID, then test the function
WITH sample_profile AS (
    SELECT ap.id
    FROM authority_profiles ap
    WHERE ap.authority_id IN (
        SELECT pr.authority_id 
        FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    )
    LIMIT 1
)
SELECT 
    'Function test' as debug_step,
    sp.id as sample_profile_id,
    'Use this ID to test the function manually' as instruction
FROM sample_profile sp;

-- 6. Manual function test (replace with actual ID from step 5)
-- SELECT update_authority_profile(
--     'your-profile-id-here'::uuid,
--     'Test Update Name',
--     true,
--     'Test update notes'
-- ) as function_result;

-- 7. Check RLS policies that might be blocking updates
SELECT 
    'RLS policies for UPDATE' as debug_step,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'authority_profiles'
AND cmd = 'UPDATE';

-- 8. Check if you can see the authority_profiles table at all
SELECT 
    'Direct table access' as debug_step,
    COUNT(*) as total_visible_records
FROM authority_profiles;

-- 9. Check current user info
SELECT 
    'Current user info' as debug_step,
    auth.uid() as user_id,
    auth.email() as user_email;