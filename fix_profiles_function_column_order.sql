-- Fix the get_profiles_by_authority_enhanced function column order
-- Drop the existing function first to avoid the return type conflict
DROP FUNCTION IF EXISTS public.get_profiles_by_authority_enhanced(uuid);

-- Recreate with the correct column order matching the original function
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
    LEFT JOIN public.authority_profiles ap ON p.id = ap.profile_id AND ap.authority_id = target_authority_id
    WHERE pr.authority_id = target_authority_id
    GROUP BY p.id, p.full_name, p.email, ap.display_name, p.profile_image_url
    ORDER BY MAX(pr.assigned_at) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_profiles_by_authority_enhanced(uuid) TO authenticated;