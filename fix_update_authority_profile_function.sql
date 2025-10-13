-- Fix the update_authority_profile function to use broader permission check
-- This aligns with the service permission fix we just made

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
    target_authority_id uuid;
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
    SELECT EXISTS (
        SELECT 1 
        FROM public.profile_roles pr
        JOIN public.roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
    ) INTO user_has_admin_role;
    
    IF NOT user_has_admin_role THEN
        RETURN FALSE;
    END IF;
    
    -- Get the authority_id of the profile being updated
    SELECT authority_id INTO target_authority_id
    FROM public.authority_profiles
    WHERE id = profile_record_id;
    
    -- Check if user is country admin for the same country as the target authority
    IF EXISTS (
        SELECT 1 
        FROM public.profile_roles pr
        JOIN public.roles r ON pr.role_id = r.id
        JOIN public.authorities a ON pr.authority_id = a.id
        JOIN public.authorities target_a ON target_a.id = target_authority_id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_administrator'
        AND pr.is_active = true
        AND a.country_id = target_a.country_id
    ) THEN
        -- User can update this authority profile
        UPDATE public.authority_profiles 
        SET 
            display_name = new_display_name,
            is_active = new_is_active,
            notes = new_notes,
            updated_at = now()
        WHERE id = profile_record_id;
        
        RETURN FOUND;
    END IF;
    
    -- No permission to update
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper permissions
GRANT EXECUTE ON FUNCTION public.update_authority_profile(uuid, text, boolean, text) TO authenticated;