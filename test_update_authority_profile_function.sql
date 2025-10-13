-- Test the update_authority_profile function

-- 1. Check if the function exists
SELECT 
    'Function exists check' as test,
    routine_name,
    routine_type,
    security_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'update_authority_profile';

-- 2. Check function parameters
SELECT 
    'Function parameters' as test,
    parameter_name,
    data_type,
    parameter_mode
FROM information_schema.parameters 
WHERE specific_name IN (
    SELECT specific_name 
    FROM information_schema.routines 
    WHERE routine_name = 'update_authority_profile'
)
ORDER BY ordinal_position;

-- 3. Check function permissions
SELECT 
    'Function permissions' as test,
    grantee,
    privilege_type
FROM information_schema.routine_privileges 
WHERE routine_name = 'update_authority_profile'
AND grantee IN ('authenticated', 'public', current_user);

-- 4. Get a sample authority_profile ID to test with
SELECT 
    'Sample authority profile for testing' as test,
    id,
    display_name,
    is_active,
    notes
FROM authority_profiles 
WHERE authority_id IN (
    SELECT pr.authority_id 
    FROM profile_roles pr
    JOIN roles r ON pr.role_id = r.id
    WHERE pr.profile_id = auth.uid()
    AND r.name = 'country_administrator'
    AND pr.is_active = true
)
LIMIT 1;

-- 5. Test the function with a sample (replace with actual ID from step 4)
-- SELECT update_authority_profile(
--     'sample-authority-profile-id',
--     'Test Display Name',
--     true,
--     'Test notes'
-- );

-- 6. Check RLS policies on authority_profiles for UPDATE
SELECT 
    'UPDATE RLS policies' as test,
    policyname,
    permissive,
    roles,
    cmd as command_type,
    qual as policy_condition
FROM pg_policies 
WHERE tablename = 'authority_profiles'
AND cmd = 'UPDATE';

-- 7. Test direct UPDATE access (this might fail due to RLS, which is expected)
-- This is just to see what error we get
-- UPDATE authority_profiles 
-- SET display_name = 'Direct Update Test'
-- WHERE id = 'some-id'
-- RETURNING id, display_name;