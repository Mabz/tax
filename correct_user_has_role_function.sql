-- =====================================================
-- CORRECT: Create profile_has_role function for actual table structure
-- =====================================================

-- Based on actual schema: profiles and profile_roles tables
-- profile_roles uses authority_id (not country_id) after migration

CREATE OR REPLACE FUNCTION profile_has_role(
  role_name text,
  country_code text DEFAULT NULL,
  profile_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_profile_id uuid;
  role_exists boolean := false;
BEGIN
  -- Use provided profile_id or current authenticated user
  target_profile_id := COALESCE(profile_id, auth.uid());
  
  -- Return false if no profile
  IF target_profile_id IS NULL THEN
    RETURN false;
  END IF;

  -- Check if profile has the role
  IF country_code IS NULL THEN
    -- Check for global roles (like superuser, traveller)
    -- For global roles, we don't filter by authority/country
    SELECT EXISTS(
      SELECT 1 
      FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      WHERE pr.profile_id = target_profile_id
        AND r.name = role_name
        AND pr.is_active = true
    ) INTO role_exists;
  ELSE
    -- Check for country-specific roles
    -- Need to join through authorities to get country
    SELECT EXISTS(
      SELECT 1 
      FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      JOIN authorities a ON a.id = pr.authority_id
      JOIN countries c ON c.id = a.country_id
      WHERE pr.profile_id = target_profile_id
        AND r.name = role_name
        AND c.country_code = country_code
        AND pr.is_active = true
        AND a.is_active = true
        AND c.is_active = true
    ) INTO role_exists;
  END IF;

  RETURN role_exists;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION profile_has_role(text, text, uuid) TO authenticated;

-- Also create a simpler version for superuser check
CREATE OR REPLACE FUNCTION is_superuser(profile_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN profile_has_role('superuser', NULL, profile_id);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_superuser(uuid) TO authenticated;

-- Create user_has_role as an alias for backward compatibility
CREATE OR REPLACE FUNCTION user_has_role(
  role_name text,
  country_code text DEFAULT NULL,
  user_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN profile_has_role(role_name, country_code, user_id);
END;
$$;

-- Grant execute permissions for backward compatibility
GRANT EXECUTE ON FUNCTION user_has_role(text, text, uuid) TO authenticated;

-- Function to get profiles by country (for country admin functionality)
-- Updated to work with authority-centric model
CREATE OR REPLACE FUNCTION get_profiles_by_country(target_country_id uuid)
RETURNS TABLE (
  profile_id uuid,
  full_name text,
  email text,
  roles text,
  latest_assigned_at timestamptz,
  any_active boolean
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    p.id as profile_id,
    p.full_name,
    p.email,
    string_agg(r.name, ', ' ORDER BY r.name) as roles,
    max(pr.assigned_at) as latest_assigned_at,
    bool_or(pr.is_active) as any_active
  FROM profile_roles pr
  JOIN profiles p ON p.id = pr.profile_id
  JOIN roles r ON r.id = pr.role_id
  JOIN authorities a ON a.id = pr.authority_id
  WHERE a.country_id = target_country_id
    AND a.is_active = true
  GROUP BY p.id, p.full_name, p.email
  ORDER BY p.full_name;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_profiles_by_country(uuid) TO authenticated;
