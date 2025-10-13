-- Debug the authentication context issue

-- 1. Check what auth.uid() returns
SELECT 
    'auth.uid() check' as test,
    auth.uid() as auth_uid_result,
    CASE 
        WHEN auth.uid() IS NULL THEN 'NULL - This is the problem!'
        ELSE 'Has value - Good!'
    END as status;

-- 2. Check JWT claims
SELECT 
    'JWT claims check' as test,
    current_setting('request.jwt.claims', true) as jwt_claims;

-- 3. Try to extract user ID from JWT
SELECT 
    'JWT user extraction' as test,
    (current_setting('request.jwt.claims', true)::json->>'sub')::uuid as user_from_jwt;

-- 4. Check if you're authenticated at all
SELECT 
    'Authentication status' as test,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN 'Authenticated via auth.uid()'
        WHEN (current_setting('request.jwt.claims', true)::json->>'sub') IS NOT NULL THEN 'Authenticated via JWT'
        ELSE 'NOT AUTHENTICATED'
    END as auth_status;

-- 5. Check your profile_roles directly (this should work if you're authenticated)
SELECT 
    'Direct profile roles check' as test,
    pr.profile_id,
    pr.authority_id,
    r.name as role_name,
    pr.is_active
FROM profile_roles pr
JOIN roles r ON pr.role_id = r.id
WHERE pr.profile_id = COALESCE(
    auth.uid(), 
    (current_setting('request.jwt.claims', true)::json->>'sub')::uuid
)
AND pr.is_active = true;