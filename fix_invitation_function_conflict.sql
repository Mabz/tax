-- Fix invitation function conflict
-- Drop the conflicting function versions and create a single consistent one

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pending_invitations_for_user();
DROP FUNCTION IF EXISTS get_pending_invitations_for_user(text);
DROP FUNCTION IF EXISTS get_pending_invitations_for_user(target_email text);

-- Create the single, correct version that uses auth.uid() to get current user
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_pending_invitations_for_user() TO authenticated;
