-- FINAL FIX: Role Invitation Functions for Authority-Centric Model
-- This file ensures all invitation functions work correctly with the authority model

-- Step 1: Drop ALL existing versions of invitation functions
DROP FUNCTION IF EXISTS accept_role_invitation(uuid);
DROP FUNCTION IF EXISTS accept_role_invitation(text);
DROP FUNCTION IF EXISTS decline_role_invitation(uuid);
DROP FUNCTION IF EXISTS decline_role_invitation(text);

-- Step 2: Verify profile_roles table structure
-- The profile_roles table should have authority_id, NOT country_id
-- If you see errors about country_id, the table structure needs to be updated

-- Step 3: Create the correct accept_role_invitation function
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
  
  IF user_profile_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;
  
  -- Get invitation details
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
  
  -- CRITICAL: Assign the role using authority_id (NOT country_id)
  -- The profile_roles table structure should be:
  -- - profile_id (uuid)
  -- - role_id (uuid) 
  -- - authority_id (uuid) <- NOT country_id
  -- - assigned_by_profile_id (uuid)
  -- - assigned_at (timestamptz)
  -- - is_active (boolean)
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
    assigned_at = NOW(),
    assigned_by_profile_id = invitation_record.invited_by_profile_id;
  
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

-- Step 4: Create the correct decline_role_invitation function
CREATE OR REPLACE FUNCTION decline_role_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_email text;
BEGIN
  -- Get current user's email
  SELECT email INTO user_email FROM auth.users WHERE id = auth.uid();
  
  IF user_email IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;
  
  -- Update invitation status to declined
  UPDATE role_invitations
  SET status = 'declined',
      responded_at = NOW()
  WHERE id = invite_id
  AND email = user_email
  AND status = 'pending';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found, already responded to, or not valid for this user';
  END IF;
  
  RAISE NOTICE 'Invitation % declined by user %', invite_id, user_email;
END;
$$;

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION accept_role_invitation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION decline_role_invitation(uuid) TO authenticated;

-- Step 6: Verify the functions exist
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines 
WHERE routine_name IN ('accept_role_invitation', 'decline_role_invitation')
AND routine_schema = 'public';

-- Step 7: Test query to verify profile_roles table structure
-- This should show authority_id column, NOT country_id
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profile_roles' 
AND table_schema = 'public'
ORDER BY ordinal_position;
