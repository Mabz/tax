-- Test the update function directly to isolate the issue

-- 1. Get your user ID and a sample authority profile ID
SELECT 
    'Test data' as step,
    auth.uid() as your_user_id,
    (
        SELECT ap.id 
        FROM authority_profiles ap
        LIMIT 1
    ) as sample_profile_id;

-- 2. Test the function with a known profile ID
-- Replace 'sample-id' with an actual ID from step 1
-- SELECT 
--     'Function test result' as step,
--     update_authority_profile(
--         'sample-id'::uuid,
--         'Test Name ' || now()::text,
--         true,
--         'Test notes ' || now()::text
--     ) as update_result;

-- 3. Check if the function has the right permissions
SELECT 
    'Function permissions' as step,
    p.grantee,
    p.privilege_type,
    p.is_grantable
FROM information_schema.routine_privileges p
WHERE p.routine_name = 'update_authority_profile'
AND p.grantee IN ('authenticated', 'public', current_user);

-- 4. Check if the function exists and is callable
SELECT 
    'Function callable check' as step,
    r.routine_name,
    r.routine_type,
    r.security_type,
    r.is_deterministic
FROM information_schema.routines r
WHERE r.routine_name = 'update_authority_profile';

-- 5. Simple permission test - do you have country_administrator role?
SELECT 
    'Permission test' as step,
    COUNT(*) as admin_role_count,
    array_agg(DISTINCT a.name) as authorities_you_admin
FROM profile_roles pr
JOIN roles r ON pr.role_id = r.id
LEFT JOIN authorities a ON pr.authority_id = a.id
WHERE pr.profile_id = auth.uid()
AND r.name = 'country_administrator'
AND pr.is_active = true;