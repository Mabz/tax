-- Add profile image URL to the authority profiles function

CREATE OR REPLACE FUNCTION public.get_authority_profiles_for_admin(admin_authority_id uuid)
RETURNS TABLE (
    id uuid,
    profile_id uuid,
    display_name text,
    is_active boolean,
    notes text,
    assigned_at timestamp with time zone,
    assigned_by_name text,
    profile_email text,
    profile_full_name text,
    profile_image_url text,
    role_names text[],
    created_at timestamp with time zone,
    updated_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ap.id,
        ap.profile_id,
        ap.display_name,
        ap.is_active,
        ap.notes,
        ap.assigned_at,
        assigner.full_name as assigned_by_name,
        p.email as profile_email,
        p.full_name as profile_full_name,
        p.profile_image_url as profile_image_url,
        ARRAY_AGG(DISTINCT r.display_name) as role_names,
        ap.created_at,
        ap.updated_at
    FROM public.authority_profiles ap
    JOIN public.profiles p ON ap.profile_id = p.id
    LEFT JOIN public.profiles assigner ON ap.assigned_by = assigner.id
    LEFT JOIN public.profile_roles pr ON pr.profile_id = ap.profile_id AND pr.authority_id = ap.authority_id AND pr.is_active = true
    LEFT JOIN public.roles r ON pr.role_id = r.id
    WHERE ap.authority_id = admin_authority_id
    GROUP BY ap.id, ap.profile_id, ap.display_name, ap.is_active, ap.notes, 
             ap.assigned_at, assigner.full_name, p.email, p.full_name, p.profile_image_url,
             ap.created_at, ap.updated_at
    ORDER BY ap.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;