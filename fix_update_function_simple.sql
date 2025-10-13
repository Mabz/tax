-- Simple fix for update_authority_profile function
-- Align with the broad permission check we use in the service

CREATE OR REPLACE FUNCTION public.update_authority_profile(
    profile_record_id uuid,
    new_display_name text,
    new_is_active boolean,
    new_notes text DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    user_is_superuser boolean;
    user_has_admin_role boolean;
BEGIN
    -- Check if user is superuser
    SELECT is_superuser() INTO user_is_superuser;
    
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
    
    -- Check if user has country_administrator role for any authority
    -- This matches RoleService.hasAdminRole() logic
    SELECT EXISTS (
        SELECT 1 
        FROM public.profile_roles pr
        JOIN public.roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) INTO user_has_admin_role;
    
    IF user_has_admin_role THEN
        -- Country administrators can update authority profiles
        -- (We rely on the service to pass the correct authority's profiles)
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