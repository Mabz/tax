-- Fix Invitation Functions for Authority-Centric Model
-- This script updates the database to use authority-based invitations

-- Step 1: Drop old country-based functions if they exist
DROP FUNCTION IF EXISTS get_all_invitations_for_country(uuid);
DROP FUNCTION IF EXISTS get_invitations_for_country(uuid);

-- Step 2: Ensure role_invitations table has authority_id column
-- Check if the migration has been applied
DO $$
BEGIN
    -- Add authority_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'role_invitations' 
        AND column_name = 'authority_id'
    ) THEN
        ALTER TABLE public.role_invitations ADD COLUMN authority_id uuid;
        
        -- Populate authority_id from country_id if country_id exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'role_invitations' 
            AND column_name = 'country_id'
        ) THEN
            -- Update authority_id based on country_id
            UPDATE public.role_invitations 
            SET authority_id = (
                SELECT a.id 
                FROM public.authorities a 
                WHERE a.country_id = role_invitations.country_id 
                AND a.is_active = true
                LIMIT 1
            )
            WHERE authority_id IS NULL;
        END IF;
        
        -- Make authority_id NOT NULL
        ALTER TABLE public.role_invitations ALTER COLUMN authority_id SET NOT NULL;
        
        -- Add foreign key constraint
        ALTER TABLE public.role_invitations 
        ADD CONSTRAINT role_invitations_authority_id_fkey 
        FOREIGN KEY (authority_id) REFERENCES public.authorities(id);
        
        -- Add index for performance
        CREATE INDEX IF NOT EXISTS idx_role_invitations_authority_id 
        ON public.role_invitations(authority_id);
    END IF;
    
    -- Drop country_id column if it exists and authority_id is populated
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'role_invitations' 
        AND column_name = 'country_id'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'role_invitations' 
        AND column_name = 'authority_id'
    ) THEN
        -- Drop foreign key constraint first
        ALTER TABLE public.role_invitations 
        DROP CONSTRAINT IF EXISTS role_invitations_country_id_fkey;
        
        -- Drop the column
        ALTER TABLE public.role_invitations DROP COLUMN IF EXISTS country_id;
    END IF;
END $$;

-- Step 3: Create the authority-based invitation function
CREATE OR REPLACE FUNCTION get_all_invitations_for_authority(target_authority_id uuid)
RETURNS TABLE (
  invitation_id uuid,
  email text,
  status text,
  invited_at timestamptz,
  responded_at timestamptz,
  expires_at timestamptz,
  role_id uuid,
  invited_by_profile_id uuid,
  role_name text,
  role_display_name text,
  role_description text,
  inviter_name text,
  inviter_email text,
  authority_name text,
  country_name text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    ri.id as invitation_id,
    ri.email,
    ri.status,
    ri.invited_at,
    ri.responded_at,
    ri.expires_at,
    ri.role_id,
    ri.invited_by_profile_id,
    r.name as role_name,
    r.display_name as role_display_name,
    r.description as role_description,
    p.full_name as inviter_name,
    p.email as inviter_email,
    a.name as authority_name,
    c.name as country_name
  FROM role_invitations ri
  JOIN roles r ON r.id = ri.role_id
  JOIN authorities a ON a.id = ri.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN profiles p ON p.id = ri.invited_by_profile_id
  WHERE ri.authority_id = target_authority_id
  ORDER BY ri.invited_at DESC;
$$;

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION get_all_invitations_for_authority(uuid) TO authenticated;

-- Step 5: Update other invitation-related functions to use authority_id

-- Update invite_user_to_role function to use authority_id
CREATE OR REPLACE FUNCTION invite_user_to_role(
  target_email text,
  target_role_name text,
  target_country_code text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invitation_id uuid;
  target_role_id uuid;
  target_authority_id uuid;
  inviter_profile_id uuid;
BEGIN
  -- Get current user's profile ID
  SELECT auth.uid() INTO inviter_profile_id;
  
  -- Get role ID
  SELECT id INTO target_role_id
  FROM roles 
  WHERE name = target_role_name;
  
  IF target_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % not found', target_role_name;
  END IF;
  
  -- Get authority ID from country code
  SELECT a.id INTO target_authority_id
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE c.country_code = target_country_code
  AND a.is_active = true
  LIMIT 1;
  
  IF target_authority_id IS NULL THEN
    RAISE EXCEPTION 'No active authority found for country code %', target_country_code;
  END IF;
  
  -- Check if invitation already exists
  IF EXISTS (
    SELECT 1 FROM role_invitations 
    WHERE email = target_email 
    AND role_id = target_role_id 
    AND authority_id = target_authority_id
    AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Invitation already exists for this email and role';
  END IF;
  
  -- Create invitation
  INSERT INTO role_invitations (
    email,
    role_id,
    authority_id,
    invited_by_profile_id,
    status,
    invited_at,
    expires_at
  ) VALUES (
    target_email,
    target_role_id,
    target_authority_id,
    inviter_profile_id,
    'pending',
    NOW(),
    NOW() + INTERVAL '7 days'
  ) RETURNING id INTO invitation_id;
  
  RETURN invitation_id;
END;
$$;

GRANT EXECUTE ON FUNCTION invite_user_to_role(text, text, text) TO authenticated;

-- Step 6: Create a bridge function for backward compatibility
-- This allows existing code to work while migration is in progress
CREATE OR REPLACE FUNCTION get_all_invitations_for_country(target_country_id uuid)
RETURNS TABLE (
  invitation_id uuid,
  email text,
  status text,
  invited_at timestamptz,
  responded_at timestamptz,
  expires_at timestamptz,
  role_id uuid,
  invited_by_profile_id uuid,
  role_name text,
  role_display_name text,
  role_description text,
  inviter_name text,
  inviter_email text,
  authority_name text,
  country_name text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  -- Find the authority for this country and call the authority function
  SELECT * FROM get_all_invitations_for_authority(
    (SELECT a.id FROM authorities a WHERE a.country_id = target_country_id AND a.is_active = true LIMIT 1)
  );
$$;

GRANT EXECUTE ON FUNCTION get_all_invitations_for_country(uuid) TO authenticated;

-- Step 7: Create get_pending_invitations_for_user function
-- This is the critical function that users need to see their invitations
CREATE OR REPLACE FUNCTION get_pending_invitations_for_user()
RETURNS TABLE (
  id uuid,
  email text,
  role_name text,
  role_description text,
  country_name text,
  country_code text,
  invited_at timestamptz,
  authority_name text,
  inviter_name text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    ri.id,
    ri.email,
    r.name as role_name,
    r.description as role_description,
    c.name as country_name,
    c.country_code,
    ri.invited_at,
    a.name as authority_name,
    p.full_name as inviter_name
  FROM role_invitations ri
  JOIN roles r ON r.id = ri.role_id
  JOIN authorities a ON a.id = ri.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN profiles p ON p.id = ri.invited_by_profile_id
  WHERE ri.email = (SELECT email FROM auth.users WHERE id = auth.uid())
  AND ri.status = 'pending'
  AND ri.expires_at > NOW()
  ORDER BY ri.invited_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_pending_invitations_for_user() TO authenticated;

-- Step 8: Create accept_role_invitation function
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
  
  -- Get invitation details
  SELECT ri.*, r.name as role_name, a.country_id
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
  
  -- Assign the role
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

GRANT EXECUTE ON FUNCTION accept_role_invitation(uuid) TO authenticated;

-- Step 9: Create decline_role_invitation function
CREATE OR REPLACE FUNCTION decline_role_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update invitation status
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

GRANT EXECUTE ON FUNCTION decline_role_invitation(uuid) TO authenticated;

-- Step 10: Create delete_role_invitation function (for admins)
CREATE OR REPLACE FUNCTION delete_role_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only allow superusers and country admins to delete invitations
  IF NOT (
    EXISTS (SELECT 1 FROM profile_roles pr JOIN roles r ON r.id = pr.role_id WHERE pr.profile_id = auth.uid() AND r.name = 'superuser' AND pr.is_active = true)
    OR
    EXISTS (SELECT 1 FROM profile_roles pr JOIN roles r ON r.id = pr.role_id WHERE pr.profile_id = auth.uid() AND r.name = 'country_admin' AND pr.is_active = true)
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions to delete invitation';
  END IF;
  
  DELETE FROM role_invitations WHERE id = invite_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_role_invitation(uuid) TO authenticated;

-- Step 11: Create resend_invitation function
CREATE OR REPLACE FUNCTION resend_invitation(invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only allow superusers and country admins to resend invitations
  IF NOT (
    EXISTS (SELECT 1 FROM profile_roles pr JOIN roles r ON r.id = pr.role_id WHERE pr.profile_id = auth.uid() AND r.name = 'superuser' AND pr.is_active = true)
    OR
    EXISTS (SELECT 1 FROM profile_roles pr JOIN roles r ON r.id = pr.role_id WHERE pr.profile_id = auth.uid() AND r.name = 'country_admin' AND pr.is_active = true)
  ) THEN
    RAISE EXCEPTION 'Insufficient permissions to resend invitation';
  END IF;
  
  -- Reset invitation to pending and extend expiry
  UPDATE role_invitations
  SET status = 'pending',
      invited_at = NOW(),
      expires_at = NOW() + INTERVAL '7 days',
      responded_at = NULL
  WHERE id = invite_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION resend_invitation(uuid) TO authenticated;

-- Step 12: Verify the setup
DO $$
BEGIN
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'role_invitations table structure:';
  
  FOR rec IN 
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns 
    WHERE table_name = 'role_invitations'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '  - %: % (%)', rec.column_name, rec.data_type, 
      CASE WHEN rec.is_nullable = 'YES' THEN 'nullable' ELSE 'not null' END;
  END LOOP;
END $$;
