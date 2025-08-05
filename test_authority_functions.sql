-- Test script to debug authority functions for country admins

-- First, let's check what profile_roles exist for the current user
SELECT 
  pr.profile_id,
  pr.role_id,
  pr.authority_id,
  pr.is_active,
  r.name as role_name,
  a.name as authority_name,
  a.code as authority_code,
  c.name as country_name
FROM profile_roles pr
JOIN roles r ON r.id = pr.role_id
JOIN authorities a ON a.id = pr.authority_id
JOIN countries c ON c.id = a.country_id
WHERE pr.profile_id = auth.uid()
AND pr.is_active = true
ORDER BY r.name, a.name;

-- Test the user_has_role function
SELECT 
  'superuser' as role_name,
  user_has_role('superuser') as has_role
UNION ALL
SELECT 
  'country_admin' as role_name,
  user_has_role('country_admin') as has_role
UNION ALL
SELECT 
  'country_auditor' as role_name,
  user_has_role('country_auditor') as has_role;

-- Test the is_superuser function
SELECT is_superuser() as is_superuser;

-- Test the get_admin_authorities function
SELECT 
  name,
  code,
  authority_type,
  country_name,
  is_active
FROM get_admin_authorities()
ORDER BY country_name, name;

-- Check if the get_admin_authorities function exists
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines 
WHERE routine_name = 'get_admin_authorities'
AND routine_schema = 'public';

-- Check current user info
SELECT 
  auth.uid() as user_id,
  (SELECT email FROM auth.users WHERE id = auth.uid()) as email;