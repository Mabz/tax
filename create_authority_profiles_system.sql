-- Create authority_profiles table and related functions
-- This implements the authority management system for country administrators

-- 1. Create the authority_profiles table
CREATE TABLE IF NOT EXISTS public.authority_profiles (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    authority_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    display_name text NOT NULL,
    is_active boolean DEFAULT true,
    assigned_by uuid,
    assigned_at timestamp with time zone DEFAULT now(),
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    CONSTRAINT authority_profiles_pkey PRIMARY KEY (id),
    CONSTRAINT authority_profiles_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id) ON DELETE CASCADE,
    CONSTRAINT authority_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT authority_profiles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.profiles(id),
    CONSTRAINT authority_profiles_unique_authority_profile UNIQUE (authority_id, profile_id)
);

-- 2. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_authority_profiles_authority_id ON public.authority_profiles(authority_id);
CREATE INDEX IF NOT EXISTS idx_authority_profiles_profile_id ON public.authority_profiles(profile_id);
CREATE INDEX IF NOT EXISTS idx_authority_profiles_is_active ON public.authority_profiles(is_active);

-- 3. Enable RLS (Row Level Security)
ALTER TABLE public.authority_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies
-- Country admins can manage authority profiles for their authority
CREATE POLICY "Country admins can manage authority profiles" ON public.authority_profiles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profile_roles pr
            JOIN public.roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name = 'country_administrator'
            AND pr.authority_id = authority_profiles.authority_id
            AND pr.is_active = true
        )
    );

-- Authority users can view their own authority profile
CREATE POLICY "Authority users can view own profile" ON public.authority_profiles
    FOR SELECT USING (profile_id = auth.uid());

-- 5. Create function to automatically create authority_profile when role is assigned
CREATE OR REPLACE FUNCTION public.create_authority_profile_on_role_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create authority_profile for authority-related roles
    IF NEW.authority_id IS NOT NULL AND NEW.is_active = true THEN
        -- Check if authority_profile already exists
        IF NOT EXISTS (
            SELECT 1 FROM public.authority_profiles 
            WHERE authority_id = NEW.authority_id 
            AND profile_id = NEW.profile_id
        ) THEN
            -- Get the profile's full_name for display_name
            INSERT INTO public.authority_profiles (
                authority_id,
                profile_id,
                display_name,
                assigned_by,
                assigned_at
            )
            SELECT 
                NEW.authority_id,
                NEW.profile_id,
                COALESCE(p.full_name, p.email), -- Use full_name or fallback to email
                NEW.assigned_by_profile_id,
                NEW.assigned_at
            FROM public.profiles p
            WHERE p.id = NEW.profile_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create trigger for automatic authority_profile creation
DROP TRIGGER IF EXISTS trigger_create_authority_profile ON public.profile_roles;
CREATE TRIGGER trigger_create_authority_profile
    AFTER INSERT OR UPDATE ON public.profile_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.create_authority_profile_on_role_assignment();

-- 7. Create function to handle authority_profile deactivation when role is deactivated
CREATE OR REPLACE FUNCTION public.handle_authority_profile_on_role_change()
RETURNS TRIGGER AS $$
BEGIN
    -- If role is being deactivated
    IF OLD.is_active = true AND NEW.is_active = false AND NEW.authority_id IS NOT NULL THEN
        -- Deactivate the authority_profile
        UPDATE public.authority_profiles 
        SET is_active = false, updated_at = now()
        WHERE authority_id = NEW.authority_id 
        AND profile_id = NEW.profile_id;
    END IF;
    
    -- If role is being reactivated
    IF OLD.is_active = false AND NEW.is_active = true AND NEW.authority_id IS NOT NULL THEN
        -- Reactivate the authority_profile
        UPDATE public.authority_profiles 
        SET is_active = true, updated_at = now()
        WHERE authority_id = NEW.authority_id 
        AND profile_id = NEW.profile_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create trigger for role changes
DROP TRIGGER IF EXISTS trigger_handle_authority_profile_role_change ON public.profile_roles;
CREATE TRIGGER trigger_handle_authority_profile_role_change
    AFTER UPDATE ON public.profile_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_authority_profile_on_role_change();

-- 9. Create function to get authority profiles for country admin
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
             ap.assigned_at, assigner.full_name, p.email, p.full_name, 
             ap.created_at, ap.updated_at
    ORDER BY ap.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Create function to update authority profile
CREATE OR REPLACE FUNCTION public.update_authority_profile(
    profile_record_id uuid,
    new_display_name text,
    new_is_active boolean,
    new_notes text DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    admin_authority_id uuid;
BEGIN
    -- Get the authority_id for the current admin
    SELECT pr.authority_id INTO admin_authority_id
    FROM public.profile_roles pr
    JOIN public.roles r ON pr.role_id = r.id
    WHERE pr.profile_id = auth.uid()
    AND r.name = 'country_administrator'
    AND pr.is_active = true
    LIMIT 1;
    
    -- Update the authority profile if admin has permission
    UPDATE public.authority_profiles 
    SET 
        display_name = new_display_name,
        is_active = new_is_active,
        notes = new_notes,
        updated_at = now()
    WHERE id = profile_record_id 
    AND authority_id = admin_authority_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Populate existing authority profiles for current users
-- This creates authority_profiles for existing profile_roles with authority_id
INSERT INTO public.authority_profiles (
    authority_id,
    profile_id,
    display_name,
    assigned_by,
    assigned_at
)
SELECT DISTINCT
    pr.authority_id,
    pr.profile_id,
    COALESCE(p.full_name, p.email) as display_name,
    pr.assigned_by_profile_id,
    pr.assigned_at
FROM public.profile_roles pr
JOIN public.profiles p ON pr.profile_id = p.id
WHERE pr.authority_id IS NOT NULL
AND pr.is_active = true
AND NOT EXISTS (
    SELECT 1 FROM public.authority_profiles ap 
    WHERE ap.authority_id = pr.authority_id 
    AND ap.profile_id = pr.profile_id
)
ON CONFLICT (authority_id, profile_id) DO NOTHING;

-- 12. Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.authority_profiles TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_authority_profiles_for_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_authority_profile(uuid, text, boolean, text) TO authenticated;