-- Fix the accept_role_invitation function parameter name issue

-- First, drop the existing function to avoid parameter name conflicts
DROP FUNCTION IF EXISTS public.accept_role_invitation(uuid);

-- Create the trigger function first (this doesn't conflict)
CREATE OR REPLACE FUNCTION public.create_authority_profile_on_role_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create authority_profile if this is a new profile_roles record
    IF TG_OP = 'INSERT' THEN
        -- Check if authority_profiles record already exists
        IF NOT EXISTS (
            SELECT 1 FROM public.authority_profiles 
            WHERE profile_id = NEW.profile_id 
            AND authority_id = NEW.authority_id
        ) THEN
            -- Get the profile's full_name for the display_name
            INSERT INTO public.authority_profiles (
                profile_id,
                authority_id,
                display_name,
                is_active,
                assigned_by,
                assigned_at,
                created_at,
                updated_at
            )
            SELECT 
                NEW.profile_id,
                NEW.authority_id,
                p.full_name, -- Use full_name as initial display_name
                true, -- Default to active
                NEW.assigned_by_profile_id,
                NEW.assigned_at,
                NOW(),
                NOW()
            FROM public.profiles p
            WHERE p.id = NEW.profile_id;
            
            -- Log the creation
            RAISE NOTICE 'Created authority_profiles record for profile_id: %, authority_id: %', NEW.profile_id, NEW.authority_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on profile_roles table
DROP TRIGGER IF EXISTS trigger_create_authority_profile_on_role_assignment ON public.profile_roles;

CREATE TRIGGER trigger_create_authority_profile_on_role_assignment
    AFTER INSERT ON public.profile_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.create_authority_profile_on_role_assignment();

-- Now recreate the accept_role_invitation function with the correct parameter name
-- Check what parameter name the existing function uses and match it
CREATE OR REPLACE FUNCTION public.accept_role_invitation(invite_id uuid)
RETURNS void AS $$
DECLARE
    invitation_record record;
    existing_role_count integer;
BEGIN
    -- Get the invitation details
    SELECT ri.*, r.name as role_name
    INTO invitation_record
    FROM public.role_invitations ri
    JOIN public.roles r ON ri.role_id = r.id
    WHERE ri.id = invite_id
    AND ri.status = 'pending';
    
    -- Check if invitation exists and is pending
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invitation not found or already processed';
    END IF;
    
    -- Check if user already has this role for this authority
    SELECT COUNT(*)
    INTO existing_role_count
    FROM public.profile_roles pr
    WHERE pr.profile_id = (
        SELECT id FROM public.profiles WHERE email = invitation_record.email
    )
    AND pr.role_id = invitation_record.role_id
    AND pr.authority_id = invitation_record.authority_id
    AND pr.is_active = true;
    
    IF existing_role_count > 0 THEN
        RAISE EXCEPTION 'User already has this role for this authority';
    END IF;
    
    -- Create the profile_roles record (this will trigger the authority_profiles creation)
    INSERT INTO public.profile_roles (
        profile_id,
        role_id,
        authority_id,
        country_id,
        assigned_by_profile_id,
        assigned_at,
        is_active,
        created_at,
        updated_at
    )
    SELECT 
        p.id,
        invitation_record.role_id,
        invitation_record.authority_id,
        invitation_record.country_id,
        invitation_record.invited_by_profile_id,
        NOW(),
        true,
        NOW(),
        NOW()
    FROM public.profiles p
    WHERE p.email = invitation_record.email;
    
    -- Update the invitation status
    UPDATE public.role_invitations
    SET 
        status = 'accepted',
        responded_at = NOW(),
        updated_at = NOW()
    WHERE id = invite_id;
    
    -- Log the acceptance
    RAISE NOTICE 'Role invitation accepted for email: %, role: %, authority: %', 
        invitation_record.email, invitation_record.role_name, invitation_record.authority_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.create_authority_profile_on_role_assignment() TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_role_invitation(uuid) TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_authority_profiles_profile_authority 
ON public.authority_profiles(profile_id, authority_id);

CREATE INDEX IF NOT EXISTS idx_authority_profiles_is_active 
ON public.authority_profiles(is_active) WHERE is_active = true;