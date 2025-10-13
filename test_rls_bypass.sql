-- Test if RLS is blocking the update

-- 1. Check current RLS policies
SELECT 
    'Current RLS policies' as test,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'authority_profiles'
ORDER BY cmd, policyname;

-- 2. Temporarily disable RLS to test (BE CAREFUL - this removes security)
-- DO NOT RUN THIS IN PRODUCTION WITHOUT UNDERSTANDING THE IMPLICATIONS
-- ALTER TABLE authority_profiles DISABLE ROW LEVEL SECURITY;

-- 3. Test update without RLS (only run after step 2)
-- UPDATE authority_profiles 
-- SET display_name = 'RLS Bypass Test'
-- WHERE id = '2364f7d5-f082-4899-9331-4b6fdc5dab36'
-- RETURNING id, display_name;

-- 4. Re-enable RLS (IMPORTANT - run this after testing)
-- ALTER TABLE authority_profiles ENABLE ROW LEVEL SECURITY;

-- 5. Alternative: Create a more permissive RLS policy for testing
DROP POLICY IF EXISTS "Country admins can manage authority profiles" ON public.authority_profiles;

CREATE POLICY "Country admins can manage authority profiles" ON public.authority_profiles
    FOR ALL USING (
        -- Allow superusers
        is_superuser() OR
        -- Allow country administrators (very broad check)
        EXISTS (
            SELECT 1 FROM public.profile_roles pr
            JOIN public.roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name = 'country_administrator'
            AND pr.is_active = true
        )
    );

-- 6. Test the function again after the new policy
SELECT 
    'Test after new policy' as test,
    update_authority_profile(
        '2364f7d5-f082-4899-9331-4b6fdc5dab36'::uuid,
        'New Policy Test',
        true,
        'Testing new RLS policy'
    ) as function_result;