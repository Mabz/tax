-- Fix role checking functions for border_official and local_authority roles
-- This addresses the issue where cloud functions may not be working for role checks

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS user_has_role(text, text, uuid);
DROP FUNCTION IF EXISTS user_has_role(text, text);
DROP FUNCTION IF EXISTS user_has_role(text);
DROP FUNCTION IF EXISTS is_superuser(uuid);
DROP FUNCTION IF EXISTS is_superuser();

-- Create the main user_has_role function that works with authority-centric model
CREATE OR REPLACE FUNCTION user_has_role(
  role_name text,
  country_code text DEFAULT NULL,
  user_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_user_id uuid;
  user_profile_id uuid;
  role_exists boolean := false;
BEGIN
  -- Use provided user_id or current authenticated user
  target_user_id := COALESCE(user_id, auth.uid());
  
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'No user ID provided and no authenticated user';
  END IF;

  -- Get the profile ID for the user
  SELECT id INTO user_profile_id
  FROM profiles
  WHERE id = target_user_id;

  IF user_profile_id IS NULL THEN
    RETURN false;
  END IF;

  -- Handle global roles (superuser, traveller) - no country/authority needed
  IF role_name IN ('superuser', 'traveller') THEN
    SELECT EXISTS(
      SELECT 1
      FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      WHERE pr.profile_id = user_profile_id
        AND r.name = role_name
        AND pr.is_active = true
    ) INTO role_exists;
    
    RETURN role_exists;
  END IF;

  -- Handle country/authority-specific roles
  IF country_code IS NOT NULL THEN
    -- Check if user has the role for the specific country through any authority
    SELECT EXISTS(
      SELECT 1
      FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      JOIN authorities a ON a.id = pr.authority_id
      JOIN countries c ON c.id = a.country_id
      WHERE pr.profile_id = user_profile_id
        AND r.name = role_name
        AND c.country_code = country_code
        AND pr.is_active = true
        AND a.is_active = true
        AND c.is_active = true
    ) INTO role_exists;
  ELSE
    -- Check if user has the role for any country/authority
    SELECT EXISTS(
      SELECT 1
      FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      WHERE pr.profile_id = user_profile_id
        AND r.name = role_name
        AND pr.is_active = true
    ) INTO role_exists;
  END IF;

  RETURN role_exists;
END;
$$;

-- Create is_superuser function
CREATE OR REPLACE FUNCTION is_superuser(user_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_has_role('superuser', NULL, user_id);
$$;

-- Create convenience functions for specific roles
CREATE OR REPLACE FUNCTION is_border_official(country_code text, user_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_has_role('border_official', country_code, user_id);
$$;

CREATE OR REPLACE FUNCTION is_local_authority(country_code text, user_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_has_role('local_authority', country_code, user_id);
$$;

CREATE OR REPLACE FUNCTION is_country_admin(country_code text, user_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_has_role('country_admin', country_code, user_id);
$$;

CREATE OR REPLACE FUNCTION is_country_auditor(country_code text, user_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT user_has_role('country_auditor', country_code, user_id);
$$;

-- Create function to get all user roles (for debugging)
CREATE OR REPLACE FUNCTION get_user_roles(user_id uuid DEFAULT NULL)
RETURNS TABLE(role_name text, country_code text, authority_name text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_user_id uuid;
  user_profile_id uuid;
BEGIN
  -- Use provided user_id or current authenticated user
  target_user_id := COALESCE(user_id, auth.uid());
  
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'No user ID provided and no authenticated user';
  END IF;

  -- Get the profile ID for the user
  SELECT id INTO user_profile_id
  FROM profiles
  WHERE id = target_user_id;

  IF user_profile_id IS NULL THEN
    RETURN;
  END IF;

  -- Return all active roles for the user
  RETURN QUERY
  SELECT 
    r.name as role_name,
    COALESCE(c.country_code, 'GLOBAL') as country_code,
    COALESCE(a.name, 'N/A') as authority_name
  FROM profile_roles pr
  JOIN roles r ON r.id = pr.role_id
  LEFT JOIN authorities a ON a.id = pr.authority_id
  LEFT JOIN countries c ON c.id = a.country_id
  WHERE pr.profile_id = user_profile_id
    AND pr.is_active = true
  ORDER BY r.name, c.country_code;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION user_has_role(text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION user_has_role(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION user_has_role(text) TO authenticated;
GRANT EXECUTE ON FUNCTION is_superuser(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_superuser() TO authenticated;
GRANT EXECUTE ON FUNCTION is_border_official(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_border_official(text) TO authenticated;
GRANT EXECUTE ON FUNCTION is_local_authority(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_local_authority(text) TO authenticated;
GRANT EXECUTE ON FUNCTION is_country_admin(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_country_admin(text) TO authenticated;
GRANT EXECUTE ON FUNCTION is_country_auditor(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_country_auditor(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_roles(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_roles() TO authenticated;

-- Test the functions (uncomment to test)
-- SELECT user_has_role('superuser');
-- SELECT user_has_role('border_official', 'KEN');
-- SELECT user_has_role('local_authority', 'ZAF');
-- SELECT * FROM get_user_roles();
