-- Fix invitation functions to work with authority-centric model
-- The profile_roles table uses authority_id, not country_id

-- Drop and recreate accept_role_invitation function
DROP FUNCTION IF EXISTS accept_role_invitation(uuid);

CREATE OR REPLACE FUNCTION accept_role_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invitation_record RECORD;
  user_profile_id uuid;
BEGIN
  -- Get current user's profile ID
  SELECT auth.uid() INTO user_profile_id;
  
  -- Get invitation details (removed the problematic country_id reference)
  SELECT ri.*, r.name as role_name
  INTO invitation_record
  FROM role_invitations ri
  JOIN roles r ON r.id = ri.role_id
  JOIN authorities a ON a.id = ri.authority_id
  WHERE ri.id = invite_id
  AND ri.email = (SELECT email FROM auth.users WHERE id = auth.uid())
  AND ri.status = 'pending'
  AND ri.expires_at > NOW();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found or not valid';
  END IF;
  
  -- Create profile if it doesn't exist
  INSERT INTO profiles (id, full_name, email, is_active)
  VALUES (
    user_profile_id,
    COALESCE((SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = user_profile_id), 'User'),
    invitation_record.email,
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    is_active = true;
  
  -- Assign the role using authority_id (not country_id)
  INSERT INTO profile_roles (
    profile_id,
    role_id,
    authority_id,
    assigned_by_profile_id,
    assigned_at,
    is_active
  ) VALUES (
    user_profile_id,
    invitation_record.role_id,
    invitation_record.authority_id,
    invitation_record.invited_by_profile_id,
    NOW(),
    true
  )
  ON CONFLICT (profile_id, role_id, authority_id) DO UPDATE SET
    is_active = true,
    assigned_at = NOW();
  
  -- Update invitation status
  UPDATE role_invitations
  SET status = 'accepted',
      responded_at = NOW()
  WHERE id = invite_id;
  
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION accept_role_invitation(uuid) TO authenticated;

-- Also fix decline_role_invitation if it exists
DROP FUNCTION IF EXISTS decline_role_invitation(uuid);

CREATE OR REPLACE FUNCTION decline_role_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update invitation status to declined
  UPDATE role_invitations
  SET status = 'declined',
      responded_at = NOW()
  WHERE id = invite_id
  AND email = (SELECT email FROM auth.users WHERE id = auth.uid())
  AND status = 'pending';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found or not valid';
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION decline_role_invitation(uuid) TO authenticated;
