-- Fix the authentication context issue in the update function

-- The problem is that auth.uid() returns null in the function context
-- We need to pass the user ID as a parameter instead of relying on auth.uid()

CREATE OR REPLACE FUNCTION public.update_authority_profile(
    profile_record_id uuid,
    new_display_name text,
    new_is_active boolean,
    new_notes text DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    current_user_id uuid;
    user_is_superuser boolean;
    user_has_admin_role boolean;
BEGIN
    -- Get the current user ID from the JWT context
    current_user_id := auth.uid();
    
    -- If auth.uid() is null, try to get it from the JWT
    IF current_user_id IS NULL THEN
        current_user_id := (current_setting('request.jwt.claims', true)::json->>'sub')::uuid;
    END IF;
    
    -- If still null, return false
    IF current_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Check if user is superuser using the user ID
    SELECT EXISTS (
        SELECT 1 FROM public.profile_roles pr
        JOIN public.roles r ON pr.role_id = r.id
        WHERE pr.profile_id = current_user_id
        AND r.name = 'superuser'
        AND pr.is_active = true
    ) INTO user_is_superuser;
    
    IF user_is_superuser THEN
        -- Superusers can update any authority profile
        UPDATE public.authority_profiles 
        SET 
            display_name = new_display_name,
            is_active = new_is_active,
            notes = new_notes,
            updated_at = now()
        WHERE id = profile_record_id;
        
        RETURN FOUND;
    END IF;
    
    -- Check if user has country_administrator role
    SELECT EXISTS (
        SELECT 1 
        FROM public.profile_roles pr
        JOIN public.roles r ON pr.role_id = r.id
        WHERE pr.profile_id = current_user_id
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) INTO user_has_admin_role;
    
    IF user_has_admin_role THEN
        -- Country administrators can update authority profiles
        UPDATE public.authority_profiles 
        SET 
            display_name = new_display_name,
            is_active = new_is_active,
            notes = new_notes,
            updated_at = now()
        WHERE id = profile_record_id;
        
        RETURN FOUND;
    END IF;
    
    -- No admin privileges
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper permissions
GRANT EXECUTE ON FUNCTION public.update_authority_profile(uuid, text, boolean, text) TO authenticated;

-- Test the fixed function
SELECT 
    'Fixed function test' as test,
    update_authority_profile(
        '2364f7d5-f082-4899-9331-4b6fdc5dab36'::uuid,
        'Auth Context Fix Test',
        true,
        'Testing auth context fix'
    ) as result;