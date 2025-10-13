-- Create enhanced function to get border officials with display names and profile images

CREATE OR REPLACE FUNCTION public.get_border_officials_for_country_enhanced(target_country_id uuid)
RETURNS TABLE (
    profile_id uuid,
    full_name text,
    email text,
    display_name text,
    profile_image_url text,
    border_count bigint,
    assigned_borders text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as profile_id,
        p.full_name,
        p.email,
        COALESCE(ap.display_name, p.full_name, p.email) as display_name,
        p.profile_image_url,
        COUNT(DISTINCT bob.border_id) as border_count,
        STRING_AGG(DISTINCT b.name, ', ' ORDER BY b.name) as assigned_borders
    FROM public.profiles p
    JOIN public.profile_roles pr ON p.id = pr.profile_id
    JOIN public.roles r ON pr.role_id = r.id
    JOIN public.authorities a ON pr.authority_id = a.id
    LEFT JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = pr.authority_id
    LEFT JOIN public.border_official_borders bob ON p.id = bob.profile_id AND bob.is_active = true
    LEFT JOIN public.borders b ON bob.border_id = b.id
    WHERE a.country_id = target_country_id
    AND r.name = 'border_official'
    AND pr.is_active = true
    GROUP BY p.id, p.full_name, p.email, ap.display_name, p.profile_image_url
    ORDER BY COALESCE(ap.display_name, p.full_name, p.email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_border_officials_for_country_enhanced(uuid) TO authenticated;

-- Also create enhanced function for border officials by country (used in dropdowns)
CREATE OR REPLACE FUNCTION public.get_border_officials_by_country_enhanced(target_country_id uuid)
RETURNS TABLE (
    id uuid,
    full_name text,
    email text,
    display_name text,
    profile_image_url text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.full_name,
        p.email,
        COALESCE(ap.display_name, p.full_name, p.email) as display_name,
        p.profile_image_url
    FROM public.profiles p
    JOIN public.profile_roles pr ON p.id = pr.profile_id
    JOIN public.roles r ON pr.role_id = r.id
    JOIN public.authorities a ON pr.authority_id = a.id
    LEFT JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = pr.authority_id
    WHERE a.country_id = target_country_id
    AND r.name = 'border_official'
    AND pr.is_active = true
    ORDER BY COALESCE(ap.display_name, p.full_name, p.email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_border_officials_by_country_enhanced(uuid) TO authenticated;