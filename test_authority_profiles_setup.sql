-- Test queries to verify authority_profiles system is working correctly

-- 1. Check if authority_profiles table exists and has data
SELECT 
    'authority_profiles table check' as test_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT authority_id) as unique_authorities,
    COUNT(DISTINCT profile_id) as unique_profiles
FROM public.authority_profiles;

-- 2. Check if triggers are working by looking at recent authority_profiles
SELECT 
    'Recent authority_profiles' as test_name,
    ap.id,
    ap.display_name,
    ap.is_active,
    a.name as authority_name,
    p.email as profile_email,
    ap.created_at
FROM public.authority_profiles ap
JOIN public.authorities a ON ap.authority_id = a.id
JOIN public.profiles p ON ap.profile_id = p.id
ORDER BY ap.created_at DESC
LIMIT 5;

-- 3. Test the get_authority_profiles_for_admin function
-- Replace 'your-authority-id-here' with an actual authority ID from your system
-- SELECT * FROM public.get_authority_profiles_for_admin('your-authority-id-here');

-- 4. Check if RLS policies are in place
SELECT 
    'RLS policies check' as test_name,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'authority_profiles';

-- 5. Check existing profile_roles that should have authority_profiles
SELECT 
    'Profile roles with authority_id' as test_name,
    COUNT(*) as profile_roles_with_authority,
    COUNT(DISTINCT pr.authority_id) as unique_authorities_in_roles,
    COUNT(DISTINCT pr.profile_id) as unique_profiles_in_roles
FROM public.profile_roles pr
WHERE pr.authority_id IS NOT NULL 
AND pr.is_active = true;

-- 6. Check for any profile_roles that don't have corresponding authority_profiles
SELECT 
    'Missing authority_profiles' as test_name,
    pr.profile_id,
    pr.authority_id,
    p.email,
    a.name as authority_name
FROM public.profile_roles pr
JOIN public.profiles p ON pr.profile_id = p.id
JOIN public.authorities a ON pr.authority_id = a.id
WHERE pr.authority_id IS NOT NULL 
AND pr.is_active = true
AND NOT EXISTS (
    SELECT 1 FROM public.authority_profiles ap 
    WHERE ap.authority_id = pr.authority_id 
    AND ap.profile_id = pr.profile_id
)
LIMIT 5;

-- 7. Sample authority IDs for testing the function
SELECT 
    'Sample authority IDs for testing' as test_name,
    id as authority_id,
    name as authority_name,
    country_id
FROM public.authorities 
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 3;