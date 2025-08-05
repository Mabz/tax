-- Border Official Management Functions for Authority-Centric Model
-- These functions support the Border Official Management screen

-- Function to get border officials for a country (works with authority model)
CREATE OR REPLACE FUNCTION get_border_officials_for_country(target_country_id uuid)
RETURNS TABLE (
  profile_id uuid,
  full_name text,
  email text,
  border_count bigint,
  assigned_borders text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    p.id as profile_id,
    p.full_name,
    p.email,
    COALESCE(COUNT(ba.border_id), 0) as border_count,
    COALESCE(string_agg(b.name, ', ' ORDER BY b.name), '') as assigned_borders
  FROM profiles p
  JOIN profile_roles pr ON pr.profile_id = p.id
  JOIN roles r ON r.id = pr.role_id
  JOIN authorities a ON a.id = pr.authority_id
  LEFT JOIN border_official_borders ba ON ba.profile_id = p.id
  LEFT JOIN borders b ON b.id = ba.border_id AND b.is_active = true
  WHERE a.country_id = target_country_id
  AND r.name = 'border_official'
  AND pr.is_active = true
  AND (pr.expires_at IS NULL OR pr.expires_at > NOW())
  GROUP BY p.id, p.full_name, p.email
  ORDER BY p.full_name;
$$;

-- Function to get assigned borders for a country
CREATE OR REPLACE FUNCTION get_assigned_borders(target_country_id uuid)
RETURNS TABLE (
  assignment_id uuid,
  border_id uuid,
  border_name text,
  border_type_label text,
  country_name text,
  official_profile_id uuid,
  official_name text,
  official_email text,
  assigned_at timestamptz
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    ba.id as assignment_id,
    ba.border_id,
    b.name as border_name,
    COALESCE(bt.label, 'Unknown') as border_type_label,
    c.name as country_name,
    ba.profile_id as official_profile_id,
    p.full_name as official_name,
    p.email as official_email,
    ba.assigned_at
  FROM border_official_borders ba
  JOIN profiles p ON p.id = ba.profile_id
  JOIN borders b ON b.id = ba.border_id
  LEFT JOIN border_types bt ON bt.id = b.border_type_id
  JOIN authorities a ON a.id = b.authority_id
  JOIN countries c ON c.id = a.country_id
  WHERE a.country_id = target_country_id
  AND b.is_active = true
  ORDER BY p.full_name, b.name;
$$;

-- Function to get unassigned borders for a country
CREATE OR REPLACE FUNCTION get_unassigned_borders_for_country(target_country_id uuid)
RETURNS TABLE (
  id uuid,
  name text,
  border_type_id uuid,
  border_type_label text,
  authority_id uuid,
  is_active boolean,
  latitude decimal,
  longitude decimal,
  description text,
  created_at timestamptz,
  updated_at timestamptz
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    b.id,
    b.name,
    b.border_type_id,
    bt.label as border_type_label,
    b.authority_id,
    b.is_active,
    b.latitude,
    b.longitude,
    b.description,
    b.created_at,
    b.updated_at
  FROM borders b
  LEFT JOIN border_types bt ON bt.id = b.border_type_id
  JOIN authorities a ON a.id = b.authority_id
  LEFT JOIN border_official_borders ba ON ba.border_id = b.id
  WHERE a.country_id = target_country_id
  AND b.is_active = true
  AND ba.border_id IS NULL
  ORDER BY b.name;
$$;

-- Function to assign a border official to a border
CREATE OR REPLACE FUNCTION assign_official_to_border(
  target_profile_id uuid,
  target_border_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if assignment already exists
  IF EXISTS (
    SELECT 1 FROM border_official_borders 
    WHERE profile_id = target_profile_id 
    AND border_id = target_border_id
  ) THEN
    RAISE EXCEPTION 'Official is already assigned to this border';
  END IF;

  -- Create the assignment
  INSERT INTO border_official_borders (profile_id, border_id, assigned_at)
  VALUES (target_profile_id, target_border_id, NOW());
END;
$$;

-- Function to revoke a border official from a border
CREATE OR REPLACE FUNCTION revoke_official_from_border(
  target_profile_id uuid,
  target_border_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Remove the assignment
  DELETE FROM border_official_borders 
  WHERE profile_id = target_profile_id 
  AND border_id = target_border_id;

  -- Check if any rows were affected
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No assignment found for this official and border';
  END IF;
END;
$$;

-- Function to get border officials by country (simple list)
CREATE OR REPLACE FUNCTION get_border_officials_by_country(target_country_id uuid)
RETURNS TABLE (
  profile_id uuid,
  full_name text,
  email text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    p.id as profile_id,
    p.full_name,
    p.email
  FROM profiles p
  JOIN profile_roles pr ON pr.profile_id = p.id
  JOIN roles r ON r.id = pr.role_id
  JOIN authorities a ON a.id = pr.authority_id
  WHERE a.country_id = target_country_id
  AND r.name = 'border_official'
  AND pr.is_active = true
  AND (pr.expires_at IS NULL OR pr.expires_at > NOW())
  ORDER BY p.full_name;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_border_officials_for_country(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_assigned_borders(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_unassigned_borders_for_country(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION assign_official_to_border(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_official_from_border(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_border_officials_by_country(uuid) TO authenticated;
