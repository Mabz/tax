-- Create a debug version of the update function with detailed logging

CREATE OR REPLACE FUNCTION public.update_authority_profile_debug(
    profile_record_id uuid,
    new_display_name text,
    new_is_active boolean,
    new_notes text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    user_is_superuser boolean;
    user_has_admin_role boolean;
    update_count integer;
    result jsonb;
BEGIN
    -- Initialize result
    result := jsonb_build_object();
    
    -- Log input parameters
    result := result || jsonb_build_object('input_profile_id', profile_record_id);
    result := result || jsonb_build_object('input_display_name', new_display_name);
    result := result || jsonb_build_object('input_is_active', new_is_active);
    result := result || jsonb_build_object('input_notes', new_notes);
    result := result || jsonb_build_object('current_user', auth.uid());
    
    -- Check if user is superuser
    SELECT is_superuser() INTO user_is_superuser;
    result := result || jsonb_build_object('is_superuser', user_is_superuser);
    
    IF user_is_superuser THEN
        -- Superusers can update any authority profile
        UPDATE public.authority_profiles 
        SET 
            display_name = new_display_name,
            is_active = new_is_active,
            notes = new_notes,
            updated_at = now()
        WHERE id = profile_record_id;
        
        GET DIAGNOSTICS update_count = ROW_COUNT;
        result := result || jsonb_build_object('superuser_update_count', update_count);
        result := result || jsonb_build_object('superuser_found', FOUND);
        result := result || jsonb_build_object('final_result', FOUND);
        
        RETURN result;
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
    
    result := result || jsonb_build_object('has_admin_role', user_has_admin_role);
    
    IF user_has_admin_role THEN
        -- Country administrators can update authority profiles
        UPDATE public.authority_profiles 
        SET 
            display_name = new_display_name,
            is_active = new_is_active,
            notes = new_notes,
            updated_at = now()
        WHERE id = profile_record_id;
        
        GET DIAGNOSTICS update_count = ROW_COUNT;
        result := result || jsonb_build_object('admin_update_count', update_count);
        result := result || jsonb_build_object('admin_found', FOUND);
        result := result || jsonb_build_object('final_result', FOUND);
        
        RETURN result;
    END IF;
    
    -- No admin privileges
    result := result || jsonb_build_object('final_result', false);
    result := result || jsonb_build_object('reason', 'no_admin_privileges');
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.update_authority_profile_debug(uuid, text, boolean, text) TO authenticated;

-- Test the debug function with your exact parameters
SELECT update_authority_profile_debug(
    '2364f7d5-f082-4899-9331-4b6fdc5dab36'::uuid,
    'Bob Miller Debug Test',
    true,
    'Debug test notes'
) as debug_result;