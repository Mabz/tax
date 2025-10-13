-- Debug why the update_authority_profile function is returning false

-- 1. Test with the exact profile ID from your debug output
SELECT 
    'Profile exists check' as test,
    id,
    display_name,
    is_active,
    notes,
    authority_id
FROM authority_profiles 
WHERE id = '2364f7d5-f082-4899-9331-4b6fdc5dab36';

-- 2. Check your permissions for this specific case
SELECT 
    'Permission check' as test,
    is_superuser() as is_superuser,
    EXISTS (
        SELECT 1 
        FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) as has_admin_role;

-- 3. Test the function manually with the exact same parameters
SELECT 
    'Manual function test' as test,
    update_authority_profile(
        '2364f7d5-f082-4899-9331-4b6fdc5dab36'::uuid,
        'Bob Miller',
        true,
        'yy'
    ) as function_result;

-- 4. Check what happens if we try to update directly
UPDATE authority_profiles 
SET 
    display_name = 'Direct Update Test',
    is_active = true,
    notes = 'Direct test notes',
    updated_at = now()
WHERE id = '2364f7d5-f082-4899-9331-4b6fdc5dab36'
RETURNING id, display_name, 'Direct update worked' as result;

-- 5. Check the current function definition to see if it was updated
SELECT 
    'Function definition' as test,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'update_authority_profile';