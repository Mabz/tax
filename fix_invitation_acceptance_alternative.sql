-- Alternative fix for invitation acceptance bug without ON CONFLICT
-- This version handles duplicates manually instead of using ON CONFLICT

-- Drop the problematic function first
DROP FUNCTION IF EXISTS accept_role_invitation(uuid);

-- Create the corrected accept_role_invitation function (without ON CONFLICT)
CREATE OR REPLACE FUNCTION accept_role_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invitation_record RECORD;
  user_profile_id uuid;
  existing_role_count integer;
BEGIN
  -- Get current user's profile ID
  SELECT auth.uid() INTO user_profile_id;
  
  IF user_profile_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;
  
  -- Get invitation details (REMOVED country_id reference)
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
    RAISE EXCEPTION 'Invitation not found, expired, or not valid for this user';
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
  
  -- Check if the role assignment already exists
  SELECT COUNT(*) INTO existing_role_count
  FROM profile_roles
  WHERE profile_id = user_profile_id
  AND role_id = invitation_record.role_id
  AND authority_id = invitation_record.authority_id;
  
  -- Assign the role using authority_id (NOT country_id)
  IF existing_role_count = 0 THEN
    -- Insert new role assignment
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
    );
  ELSE
    -- Update existing role assignment
    UPDATE profile_roles
    SET is_active = true,
        assigned_at = NOW(),
        assigned_by_profile_id = invitation_record.invited_by_profile_id
    WHERE profile_id = user_profile_id
    AND role_id = invitation_record.role_id
    AND authority_id = invitation_record.authority_id;
  END IF;
  
  -- Update invitation status
  UPDATE role_invitations
  SET status = 'accepted',
      responded_at = NOW()
  WHERE id = invite_id;
  
  RAISE NOTICE 'Role % assigned to user % for authority %', 
    invitation_record.role_name, 
    user_profile_id, 
    invitation_record.authority_id;
  
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION accept_role_invitation(uuid) TO authenticated;

-- Verify the function was created correctly
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines 
WHERE routine_name = 'accept_role_invitation'
AND routine_schema = 'public';