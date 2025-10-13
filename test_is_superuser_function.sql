-- Test if the is_superuser() function exists and works

-- 1. Check if is_superuser function exists
SELECT 
    'is_superuser function check' as test,
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'is_superuser';

-- 2. Test calling is_superuser directly
SELECT 
    'is_superuser test' as test,
    is_superuser() as result;

-- 3. Create a version of update function without is_superuser call
CREATE OR REPLACE FUNCTION public.update_authority_profile_no_superuser(
    profile_record_id uuid,
    new_display_name text,
    new_is_active boolean,
    new_notes text DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    user_has_admin_role boolean;
BEGIN
    -- Skip superuser check, just check admin role
    SELECT EXISTS (
        SELECT 1 
        FROM public.profile_roles pr
        JOIN public.roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) INTO user_has_admin_role;
    
    IF user_has_admin_role THEN
        UPDATE public.authority_profiles 
        SET 
            display_name = new_display_name,
            is_active = new_is_active,
            notes = new_notes,
            updated_at = now()
        WHERE id = profile_record_id;
        
        RETURN FOUND;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_authority_profile_no_superuser(uuid, text, boolean, text) TO authenticated;

-- 4. Test the version without superuser check
SELECT 
    'No superuser function test' as test,
    update_authority_profile_no_superuser(
        '558b7408-f858-4392-836b-c5b6231a78cd'::uuid,
        'No Superuser Test',
        true,
        'No superuser test notes'
    ) as no_superuser_result;