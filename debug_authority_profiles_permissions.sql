-- Debug queries to check authority profiles permissions

-- 1. Check your current user's profile_roles
-- Replace 'your-user-id' with your actual user ID from auth.users
SELECT 
    'Your profile roles' as debug_info,
    pr.profile_id,
    pr.authority_id,
    pr.is_active,
    r.name as role_name,
    a.name as authority_name,
    c.name as country_name
FROM profile_roles pr
JOIN roles r ON pr.role_id = r.id
LEFT JOIN authorities a ON pr.authority_id = a.id
LEFT JOIN countries c ON a.country_id = c.id
WHERE pr.profile_id = auth.uid() -- This will use your current logged-in user
ORDER BY pr.created_at DESC;

-- 2. Check if you have country_administrator role
SELECT 
    'Country admin check' as debug_info,
    COUNT(*) as country_admin_roles,
    array_agg(DISTINCT a.name) as authorities_you_admin
FROM profile_roles pr
JOIN roles r ON pr.role_id = r.id
JOIN authorities a ON pr.authority_id = a.id
WHERE pr.profile_id = auth.uid()
AND r.name = 'country_administrator'
AND pr.is_active = true;

-- 3. Check authority_profiles for authorities you manage
SELECT 
    'Authority profiles you can manage' as debug_info,
    ap.id,
    ap.display_name,
    ap.is_active,
    a.name as authority_name,
    p.email as user_email
FROM authority_profiles ap
JOIN authorities a ON ap.authority_id = a.id
JOIN profiles p ON ap.profile_id = p.id
WHERE ap.authority_id IN (
    SELECT pr.authority_id 
    FROM profile_roles pr
    JOIN roles r ON pr.role_id = r.id
    WHERE pr.profile_id = auth.uid()
    AND r.name = 'country_administrator'
    AND pr.is_active = true
)
ORDER BY a.name, ap.display_name;

-- 4. Test the get_authority_profiles_for_admin function
-- This will show what the function returns for your authorities
SELECT 
    'Function test' as debug_info,
    authority_id,
    COUNT(*) as profile_count
FROM (
    SELECT DISTINCT pr.authority_id
    FROM profile_roles pr
    JOIN roles r ON pr.role_id = r.id
    WHERE pr.profile_id = auth.uid()
    AND r.name = 'country_administrator'
    AND pr.is_active = true
) admin_authorities
CROSS JOIN LATERAL (
    SELECT * FROM get_authority_profiles_for_admin(admin_authorities.authority_id)
) profiles
GROUP BY authority_id;

-- 5. Check RLS policies on authority_profiles
SELECT 
    'RLS policy check' as debug_info,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'authority_profiles';

-- 6. Simple test - can you see any authority_profiles at all?
SELECT 
    'Direct authority_profiles access' as debug_info,
    COUNT(*) as total_records_visible
FROM authority_profiles;

-- 7. Check if the is_superuser function works
SELECT 
    'Superuser check' as debug_info,
    is_superuser() as you_are_superuser;