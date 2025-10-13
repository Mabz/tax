-- Test the specific profile ID that's failing: 558b7408-f858-4392-836b-c5b6231a78cd

-- 1. Check if this profile exists
SELECT 
    'Profile exists check' as test,
    id,
    display_name,
    is_active,
    notes,
    authority_id,
    created_at,
    updated_at
FROM authority_profiles 
WHERE id = '558b7408-f858-4392-836b-c5b6231a78cd';

-- 2. Run the debug function with the exact parameters from your Flutter log
SELECT 
    'Debug function result' as test,
    update_authority_profile_debug(
        '558b7408-f858-4392-836b-c5b6231a78cd'::uuid,
        'Mark Smith',
        true,
        'hhhh'
    ) as debug_result;

-- 3. Check if the function was actually updated (maybe it's still the old version)
SELECT 
    'Function definition check' as test,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'update_authority_profile';

-- 4. Test direct UPDATE on this specific record (should work with RLS disabled)
UPDATE authority_profiles 
SET 
    display_name = 'Direct Update Test ' || now()::text,
    notes = 'Direct update notes',
    updated_at = now()
WHERE id = '558b7408-f858-4392-836b-c5b6231a78cd'
RETURNING id, display_name, notes, updated_at;

-- 5. Check your current user and permissions
SELECT 
    'Current user info' as test,
    auth.uid() as user_id,
    auth.email() as user_email,
    is_superuser() as is_superuser,
    EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) as has_admin_role;