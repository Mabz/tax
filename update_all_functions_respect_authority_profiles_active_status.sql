-- Update all functions to respect the is_active status from authority_profiles table
-- When a user is disabled in authority_profiles, they should not appear anywhere

-- 1. Update get_profiles_by_authority_enhanced to only show active authority profiles
DROP FUNCTION IF EXISTS public.get_profiles_by_authority_enhanced(uuid);

CREATE OR REPLACE FUNCTION public.get_profiles_by_authority_enhanced(target_authority_id uuid)
RETURNS TABLE (
    profile_id uuid,
    full_name text,
    email text,
    display_name text,
    roles text,
    latest_assigned_at timestamp with time zone,
    any_active boolean,
    profile_image_url text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as profile_id,
        p.full_name,
        p.email,
        COALESCE(ap.display_name, p.full_name, p.email) as display_name,
        STRING_AGG(DISTINCT r.display_name, ', ' ORDER BY r.display_name) as roles,
        MAX(pr.assigned_at) as latest_assigned_at,
        BOOL_OR(pr.is_active) as any_active,
        p.profile_image_url
    FROM public.profiles p
    JOIN public.profile_roles pr ON p.id = pr.profile_id
    JOIN public.roles r ON pr.role_id = r.id
    JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = target_authority_id
    WHERE pr.authority_id = target_authority_id
    AND pr.is_active = true
    AND ap.is_active = true  -- Only show active authority profiles
    GROUP BY p.id, p.full_name, p.email, ap.display_name, p.profile_image_url
    ORDER BY MAX(pr.assigned_at) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update get_border_officials_for_authority_enhanced to only show active authority profiles
DROP FUNCTION IF EXISTS public.get_border_officials_for_authority_enhanced(uuid);

CREATE OR REPLACE FUNCTION public.get_border_officials_for_authority_enhanced(target_authority_id uuid)
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
    JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = target_authority_id
    LEFT JOIN public.border_official_borders bob ON p.id = bob.profile_id AND bob.is_active = true
    LEFT JOIN public.borders b ON bob.border_id = b.id AND b.authority_id = target_authority_id
    WHERE pr.authority_id = target_authority_id
    AND r.name = 'border_official'
    AND pr.is_active = true
    AND ap.is_active = true  -- Only show active authority profiles
    GROUP BY p.id, p.full_name, p.email, ap.display_name, p.profile_image_url
    ORDER BY COALESCE(ap.display_name, p.full_name, p.email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update get_border_officials_by_authority_enhanced to only show active authority profiles
DROP FUNCTION IF EXISTS public.get_border_officials_by_authority_enhanced(uuid);

CREATE OR REPLACE FUNCTION public.get_border_officials_by_authority_enhanced(target_authority_id uuid)
RETURNS TABLE (
    profile_id uuid,
    full_name text,
    email text,
    display_name text,
    profile_image_url text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as profile_id,
        p.full_name,
        p.email,
        COALESCE(ap.display_name, p.full_name, p.email) as display_name,
        p.profile_image_url
    FROM public.profiles p
    JOIN public.profile_roles pr ON p.id = pr.profile_id
    JOIN public.roles r ON pr.role_id = r.id
    JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = target_authority_id
    WHERE pr.authority_id = target_authority_id
    AND r.name = 'border_official'
    AND pr.is_active = true
    AND ap.is_active = true  -- Only show active authority profiles
    ORDER BY COALESCE(ap.display_name, p.full_name, p.email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update get_border_assignments_with_permissions_by_authority to only show active authority profiles
DROP FUNCTION IF EXISTS public.get_border_assignments_with_permissions_by_authority(uuid);

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
    JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = authority_id_param
    WHERE b.authority_id = authority_id_param
    AND bob.is_active = true
    AND ap.is_active = true  -- Only show active authority profiles
    ORDER BY bob.assigned_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update get_border_assignments_with_permissions (country-based) to only show active authority profiles
DROP FUNCTION IF EXISTS public.get_border_assignments_with_permissions(uuid);

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
    JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = a.id
    WHERE a.country_id = country_id_param
    AND bob.is_active = true
    AND ap.is_active = true  -- Only show active authority profiles
    ORDER BY bob.assigned_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create function to get admin authorities (for dropdown) - only show authorities where user is active
CREATE OR REPLACE FUNCTION public.get_admin_authorities_for_user(user_id uuid)
RETURNS TABLE (
    id uuid,
    name text,
    country_id uuid,
    country_name text,
    country_code text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.name,
        a.country_id,
        c.name as country_name,
        c.country_code
    FROM public.authorities a
    JOIN public.countries c ON a.country_id = c.id
    JOIN public.profile_roles pr ON pr.authority_id = a.id
    JOIN public.roles r ON pr.role_id = r.id
    JOIN public.authority_profiles ap ON ap.profile_id = user_id AND ap.authority_id = a.id
    WHERE pr.profile_id = user_id
    AND r.name = 'country_admin'
    AND pr.is_active = true
    AND ap.is_active = true  -- Only show authorities where user is active
    AND a.is_active = true
    ORDER BY a.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_profiles_by_authority_enhanced(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_border_officials_for_authority_enhanced(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_border_officials_by_authority_enhanced(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_border_assignments_with_permissions_by_authority(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_border_assignments_with_permissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_authorities_for_user(uuid) TO authenticated;