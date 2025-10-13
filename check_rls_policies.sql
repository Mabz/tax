-- Check if RLS policies are blocking the update

-- 1. Check all RLS policies on authority_profiles
SELECT 
    'All RLS policies' as check_type,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as condition,
    with_check
FROM pg_policies 
WHERE tablename = 'authority_profiles'
ORDER BY cmd, policyname;

-- 2. Check if RLS is enabled
SELECT 
    'RLS status' as check_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    forcerowsecurity as force_rls
FROM pg_tables 
WHERE tablename = 'authority_profiles';

-- 3. Test if you can update directly (this might fail, but will show the error)
-- DO NOT RUN THIS - just for reference to see what error occurs
-- UPDATE authority_profiles 
-- SET display_name = 'Direct Test'
-- WHERE id = 'some-id';

-- 4. Check what the current RLS policy allows for your user
SELECT 
    'Your profile roles for RLS' as check_type,
    pr.authority_id,
    pr.profile_id,
    pr.is_active,
    r.name as role_name,
    a.name as authority_name
FROM profile_roles pr
JOIN roles r ON pr.role_id = r.id
LEFT JOIN authorities a ON pr.authority_id = a.id
WHERE pr.profile_id = auth.uid()
AND pr.is_active = true;

-- 5. Check the exact RLS condition for country admins
SELECT 
    'RLS condition test' as check_type,
    EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.authority_id = authority_profiles.authority_id
        AND pr.is_active = true
    ) as rls_condition_result
FROM authority_profiles
LIMIT 1;