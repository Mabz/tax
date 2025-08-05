-- =====================================================
-- MIGRATE USER FUNCTIONS TO PROFILE FUNCTIONS
-- =====================================================
-- This script renames all user-related functions to profile-related functions
-- for consistency with the profiles/profile_roles schema

-- Drop old user-based functions first
DROP FUNCTION IF EXISTS user_has_role(text, text, uuid);
DROP FUNCTION IF EXISTS get_passes_for_user(uuid);
DROP FUNCTION IF EXISTS get_pending_invitations_for_user(uuid);
DROP FUNCTION IF EXISTS invite_user_to_role(text, text, uuid, uuid);
DROP FUNCTION IF EXISTS get_vehicles_for_user(uuid);

-- =====================================================
-- 1. PROFILE ROLE CHECKING FUNCTIONS
-- =====================================================

-- Main profile role checking function
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

-- Superuser check function
CREATE OR REPLACE FUNCTION is_superuser(profile_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN profile_has_role('superuser', NULL, profile_id);
END;
$$;

-- =====================================================
-- 2. PROFILE PASSES FUNCTIONS
-- =====================================================

-- Get passes for a profile
CREATE OR REPLACE FUNCTION get_passes_for_profile(target_profile_id uuid DEFAULT NULL)
RETURNS TABLE (
  pass_id uuid,
  profile_id uuid,
  vehicle_id uuid,
  pass_template_id uuid,
  issued_at timestamptz,
  expires_at timestamptz,
  entries_remaining int,
  status text,
  pass_hash text,
  short_code text,
  qr_data jsonb,
  -- Template details
  template_description text,
  entry_limit int,
  expiration_days int,
  tax_amount numeric,
  currency_code text,
  -- Vehicle details
  vehicle_number_plate text,
  vehicle_description text,
  -- Authority/Country details
  authority_name text,
  country_name text,
  country_code text,
  -- Border details
  border_name text
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    pp.id as pass_id,
    pp.profile_id,
    pp.vehicle_id,
    pp.pass_template_id,
    pp.issued_at,
    pp.expires_at,
    pp.entries_remaining,
    pp.status,
    pp.pass_hash,
    pp.short_code,
    pp.qr_data,
    -- Template details
    pt.description as template_description,
    pt.entry_limit,
    pt.expiration_days,
    pt.tax_amount,
    pt.currency_code,
    -- Vehicle details
    v.number_plate as vehicle_number_plate,
    v.description as vehicle_description,
    -- Authority/Country details
    a.name as authority_name,
    c.name as country_name,
    c.country_code,
    -- Border details
    b.name as border_name
  FROM purchased_passes pp
  JOIN pass_templates pt ON pt.id = pp.pass_template_id
  LEFT JOIN vehicles v ON v.id = pp.vehicle_id
  JOIN authorities a ON a.id = pt.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN borders b ON b.id = pt.border_id
  WHERE pp.profile_id = COALESCE(target_profile_id, auth.uid())
  ORDER BY pp.issued_at DESC;
$$;

-- =====================================================
-- 3. PROFILE INVITATIONS FUNCTIONS
-- =====================================================

-- Get pending invitations for a profile
CREATE OR REPLACE FUNCTION get_pending_invitations_for_profile(target_email text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  email text,
  role_name text,
  role_description text,
  authority_name text,
  country_name text,
  country_code text,
  invited_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    ri.id,
    ri.email,
    r.name as role_name,
    r.description as role_description,
    a.name as authority_name,
    c.name as country_name,
    c.country_code,
    ri.invited_at
  FROM role_invitations ri
  JOIN roles r ON r.id = ri.role_id
  JOIN authorities a ON a.id = ri.authority_id
  JOIN countries c ON c.id = a.country_id
  WHERE ri.email = COALESCE(target_email, (SELECT email FROM auth.users WHERE id = auth.uid()))
    AND ri.status = 'pending'
    AND (ri.expires_at IS NULL OR ri.expires_at > now())
  ORDER BY ri.invited_at DESC;
$$;

-- Invite profile to role
CREATE OR REPLACE FUNCTION invite_profile_to_role(
  target_email text,
  role_name text,
  authority_id uuid,
  invited_by_profile_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  role_id uuid;
  invitation_id uuid;
  inviter_id uuid;
BEGIN
  -- Get the inviter profile ID
  inviter_id := COALESCE(invited_by_profile_id, auth.uid());
  
  -- Get role ID
  SELECT id INTO role_id FROM roles WHERE name = role_name;
  IF role_id IS NULL THEN
    RAISE EXCEPTION 'Role % not found', role_name;
  END IF;
  
  -- Check if invitation already exists
  IF EXISTS (
    SELECT 1 FROM role_invitations 
    WHERE email = target_email 
      AND role_id = invite_profile_to_role.role_id 
      AND authority_id = invite_profile_to_role.authority_id
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
    role_id,
    authority_id,
    inviter_id,
    'pending',
    now(),
    now() + interval '7 days'
  ) RETURNING id INTO invitation_id;
  
  RETURN invitation_id;
END;
$$;

-- =====================================================
-- 4. PROFILE VEHICLES FUNCTIONS
-- =====================================================

-- Get vehicles for a profile
CREATE OR REPLACE FUNCTION get_vehicles_for_profile(target_profile_id uuid DEFAULT NULL)
RETURNS TABLE (
  vehicle_id uuid,
  profile_id uuid,
  number_plate text,
  description text,
  vin_number text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    v.id as vehicle_id,
    v.profile_id,
    v.number_plate,
    v.description,
    v.vin_number,
    v.created_at,
    v.updated_at
  FROM vehicles v
  WHERE v.profile_id = COALESCE(target_profile_id, auth.uid())
  ORDER BY v.created_at DESC;
$$;

-- =====================================================
-- 5. PROFILE MANAGEMENT FUNCTIONS
-- =====================================================

-- Get profiles by country (for country admin functionality)
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

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION profile_has_role(text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION is_superuser(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_passes_for_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_invitations_for_profile(text) TO authenticated;
GRANT EXECUTE ON FUNCTION invite_profile_to_role(text, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_vehicles_for_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_profiles_by_country(uuid) TO authenticated;

-- =====================================================
-- 7. BACKWARD COMPATIBILITY ALIASES
-- =====================================================

-- Create user_* functions as aliases for backward compatibility
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

CREATE OR REPLACE FUNCTION get_passes_for_user(target_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  pass_id uuid,
  profile_id uuid,
  vehicle_id uuid,
  pass_template_id uuid,
  issued_at timestamptz,
  expires_at timestamptz,
  entries_remaining int,
  status text,
  pass_hash text,
  short_code text,
  qr_data jsonb,
  template_description text,
  entry_limit int,
  expiration_days int,
  tax_amount numeric,
  currency_code text,
  vehicle_number_plate text,
  vehicle_description text,
  authority_name text,
  country_name text,
  country_code text,
  border_name text
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM get_passes_for_profile(target_user_id);
$$;

CREATE OR REPLACE FUNCTION get_pending_invitations_for_user(target_email text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  email text,
  role_name text,
  role_description text,
  authority_name text,
  country_name text,
  country_code text,
  invited_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM get_pending_invitations_for_profile(target_email);
$$;

CREATE OR REPLACE FUNCTION invite_user_to_role(
  target_email text,
  role_name text,
  authority_id uuid,
  invited_by_user_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN invite_profile_to_role(target_email, role_name, authority_id, invited_by_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION get_vehicles_for_user(target_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  vehicle_id uuid,
  profile_id uuid,
  number_plate text,
  description text,
  vin_number text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM get_vehicles_for_profile(target_user_id);
$$;

-- Grant permissions for backward compatibility functions
GRANT EXECUTE ON FUNCTION user_has_role(text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_passes_for_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_invitations_for_user(text) TO authenticated;
GRANT EXECUTE ON FUNCTION invite_user_to_role(text, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_vehicles_for_user(uuid) TO authenticated;
