-- Create function to get border assignments with permissions and display names from authority_profiles

-- First, create the country-based function (for backward compatibility)
CREATE OR REPLACE FUNCTION public.get_border_assignments_with_permissions(country_id_param uuid)
RETURNS TABLE (
    id uuid,
    profile_id uuid,
    border_id uuid,
    official_name text,
    official_email text,
    official_display_name text,
    official_profile_image_url text,
    border_name text,
    can_check_in boolean,
    can_check_out boolean,
    assigned_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bob.id,
        bob.profile_id,
        bob.border_id,
        p.full_name as official_name,
        p.email as official_email,
        COALESCE(ap.display_name, p.full_name, p.email) as official_display_name,
        p.profile_image_url as official_profile_image_url,
        b.name as border_name,
        bob.can_check_in,
        bob.can_check_out,
        bob.assigned_at
    FROM public.border_official_borders bob
    JOIN public.profiles p ON bob.profile_id = p.id
    JOIN public.borders b ON bob.border_id = b.id
    JOIN public.authorities a ON b.authority_id = a.id
    LEFT JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = a.id
    WHERE a.country_id = country_id_param
    AND bob.is_active = true
    ORDER BY bob.assigned_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the authority-based function (preferred for authority-specific contexts)
CREATE OR REPLACE FUNCTION public.get_border_assignments_with_permissions_by_authority(authority_id_param uuid)
RETURNS TABLE (
    id uuid,
    profile_id uuid,
    border_id uuid,
    official_name text,
    official_email text,
    official_display_name text,
    official_profile_image_url text,
    border_name text,
    can_check_in boolean,
    can_check_out boolean,
    assigned_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bob.id,
        bob.profile_id,
        bob.border_id,
        p.full_name as official_name,
        p.email as official_email,
        COALESCE(ap.display_name, p.full_name, p.email) as official_display_name,
        p.profile_image_url as official_profile_image_url,
        b.name as border_name,
        bob.can_check_in,
        bob.can_check_out,
        bob.assigned_at
    FROM public.border_official_borders bob
    JOIN public.profiles p ON bob.profile_id = p.id
    JOIN public.borders b ON bob.border_id = b.id
    LEFT JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = authority_id_param
    WHERE b.authority_id = authority_id_param
    AND bob.is_active = true
    ORDER BY bob.assigned_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_border_assignments_with_permissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_border_assignments_with_permissions_by_authority(uuid) TO authenticated;