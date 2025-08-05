-- Authority Management Database Functions
-- Enhanced with pass_advance_days and default_currency_code fields

-- Function to get all authorities with country information (for superuser)
CREATE OR REPLACE FUNCTION get_all_authorities()
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
  pass_advance_days integer,
  default_currency_code text,
  created_at timestamptz,
  updated_at timestamptz,
  country_name text,
  country_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    a.id,
    a.country_id,
    a.name,
    a.code,
    a.authority_type,
    a.description,
    a.is_active,
    a.pass_advance_days,
    a.default_currency_code,
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  ORDER BY c.name, a.name;
$$;

-- Function to get active authorities with country information
CREATE OR REPLACE FUNCTION get_active_authorities()
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
  pass_advance_days integer,
  default_currency_code text,
  created_at timestamptz,
  updated_at timestamptz,
  country_name text,
  country_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    a.id,
    a.country_id,
    a.name,
    a.code,
    a.authority_type,
    a.description,
    a.is_active,
    a.pass_advance_days,
    a.default_currency_code,
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE a.is_active = true
  ORDER BY c.name, a.name;
$$;

-- Function to get authorities for a specific country
CREATE OR REPLACE FUNCTION get_authorities_for_country(target_country_id uuid)
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
  pass_advance_days integer,
  default_currency_code text,
  created_at timestamptz,
  updated_at timestamptz,
  country_name text,
  country_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    a.id,
    a.country_id,
    a.name,
    a.code,
    a.authority_type,
    a.description,
    a.is_active,
    a.pass_advance_days,
    a.default_currency_code,
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE a.country_id = target_country_id
  ORDER BY a.name;
$$;

-- Function to create a new authority
CREATE OR REPLACE FUNCTION create_authority(
  target_country_id uuid,
  authority_name text,
  authority_code text,
  authority_type text,
  authority_description text DEFAULT NULL,
  authority_pass_advance_days integer DEFAULT 30,
  authority_default_currency_code text DEFAULT NULL,
  authority_is_active boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_authority_id uuid;
BEGIN
  -- Check if user is superuser
  IF NOT is_superuser() THEN
    RAISE EXCEPTION 'Only superusers can create authorities';
  END IF;

  -- Validate inputs
  IF trim(authority_name) = '' THEN
    RAISE EXCEPTION 'Authority name cannot be empty';
  END IF;

  IF trim(authority_code) = '' THEN
    RAISE EXCEPTION 'Authority code cannot be empty';
  END IF;

  IF authority_pass_advance_days < 1 OR authority_pass_advance_days > 365 THEN
    RAISE EXCEPTION 'Pass advance days must be between 1 and 365';
  END IF;

  -- Check if country exists
  IF NOT EXISTS (SELECT 1 FROM countries WHERE id = target_country_id) THEN
    RAISE EXCEPTION 'Country not found';
  END IF;

  -- Check if authority code is unique within the country
  IF EXISTS (
    SELECT 1 FROM authorities 
    WHERE country_id = target_country_id 
    AND UPPER(code) = UPPER(trim(authority_code))
  ) THEN
    RAISE EXCEPTION 'Authority code already exists in this country';
  END IF;

  -- Check if currency code exists (if provided)
  IF authority_default_currency_code IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM currencies WHERE code = authority_default_currency_code) THEN
      RAISE EXCEPTION 'Currency code not found';
    END IF;
  END IF;

  -- Insert new authority
  INSERT INTO authorities (
    id,
    country_id,
    name,
    code,
    authority_type,
    description,
    pass_advance_days,
    default_currency_code,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    target_country_id,
    trim(authority_name),
    UPPER(trim(authority_code)),
    trim(authority_type),
    NULLIF(trim(authority_description), ''),
    authority_pass_advance_days,
    authority_default_currency_code,
    authority_is_active,
    now(),
    now()
  ) RETURNING id INTO new_authority_id;

  RETURN new_authority_id;
END;
$$;

-- Function to update an existing authority
CREATE OR REPLACE FUNCTION update_authority(
  target_authority_id uuid,
  new_name text,
  new_code text,
  new_authority_type text,
  new_description text DEFAULT NULL,
  new_pass_advance_days integer DEFAULT 30,
  new_default_currency_code text DEFAULT NULL,
  new_is_active boolean DEFAULT true
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is superuser
  IF NOT is_superuser() THEN
    RAISE EXCEPTION 'Only superusers can update authorities';
  END IF;

  -- Validate inputs
  IF trim(new_name) = '' THEN
    RAISE EXCEPTION 'Authority name cannot be empty';
  END IF;

  IF trim(new_code) = '' THEN
    RAISE EXCEPTION 'Authority code cannot be empty';
  END IF;

  IF new_pass_advance_days < 1 OR new_pass_advance_days > 365 THEN
    RAISE EXCEPTION 'Pass advance days must be between 1 and 365';
  END IF;

  -- Check if authority exists
  IF NOT EXISTS (SELECT 1 FROM authorities WHERE id = target_authority_id) THEN
    RAISE EXCEPTION 'Authority not found';
  END IF;

  -- Check if new code conflicts with existing authorities in same country
  IF EXISTS (
    SELECT 1 FROM authorities a1
    WHERE a1.id != target_authority_id
    AND a1.country_id = (SELECT country_id FROM authorities WHERE id = target_authority_id)
    AND UPPER(a1.code) = UPPER(trim(new_code))
  ) THEN
    RAISE EXCEPTION 'Authority code already exists in this country';
  END IF;

  -- Check if currency code exists (if provided)
  IF new_default_currency_code IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM currencies WHERE code = new_default_currency_code) THEN
      RAISE EXCEPTION 'Currency code not found';
    END IF;
  END IF;

  -- Update authority
  UPDATE authorities SET
    name = trim(new_name),
    code = UPPER(trim(new_code)),
    authority_type = trim(new_authority_type),
    description = NULLIF(trim(new_description), ''),
    pass_advance_days = new_pass_advance_days,
    default_currency_code = new_default_currency_code,
    is_active = new_is_active,
    updated_at = now()
  WHERE id = target_authority_id;

  RETURN true;
END;
$$;

-- Function to delete an authority (soft delete by setting is_active = false)
CREATE OR REPLACE FUNCTION delete_authority(target_authority_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is superuser
  IF NOT is_superuser() THEN
    RAISE EXCEPTION 'Only superusers can delete authorities';
  END IF;

  -- Check if authority exists
  IF NOT EXISTS (SELECT 1 FROM authorities WHERE id = target_authority_id) THEN
    RAISE EXCEPTION 'Authority not found';
  END IF;

  -- Check if authority is being used
  IF EXISTS (
    SELECT 1 FROM profile_roles WHERE authority_id = target_authority_id
    UNION ALL
    SELECT 1 FROM borders WHERE authority_id = target_authority_id
    UNION ALL
    SELECT 1 FROM pass_templates WHERE authority_id = target_authority_id
    UNION ALL
    SELECT 1 FROM vehicle_tax_rates WHERE authority_id = target_authority_id
  ) THEN
    RAISE EXCEPTION 'Cannot delete authority that is being used by other records';
  END IF;

  -- Soft delete by setting is_active = false
  UPDATE authorities SET
    is_active = false,
    updated_at = now()
  WHERE id = target_authority_id;

  RETURN true;
END;
$$;

-- Function to get authority types for dropdown
CREATE OR REPLACE FUNCTION get_authority_types()
RETURNS TABLE (
  authority_type text,
  display_name text,
  description text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    'revenue_service'::text as authority_type,
    'Revenue Service'::text as display_name,
    'Tax collection and revenue management'::text as description
  UNION ALL
  SELECT 
    'customs'::text,
    'Customs Authority'::text,
    'Import/export and border control'::text
  UNION ALL
  SELECT 
    'immigration'::text,
    'Immigration Authority'::text,
    'Immigration and border control'::text
  UNION ALL
  SELECT 
    'transport'::text,
    'Transport Authority'::text,
    'Vehicle registration and transport regulation'::text
  UNION ALL
  SELECT 
    'default'::text,
    'Default Authority'::text,
    'General governmental authority'::text
  UNION ALL
  SELECT 
    'global'::text,
    'Global Authority'::text,
    'System-wide authority for global operations'::text
  ORDER BY 1;
$$;

-- Function: Get authorities that the current user can administer
CREATE OR REPLACE FUNCTION get_admin_authorities()
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
  pass_advance_days integer,
  default_currency_code text,
  created_at timestamptz,
  updated_at timestamptz,
  country_name text,
  country_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    a.id,
    a.country_id,
    a.name,
    a.code,
    a.authority_type,
    a.description,
    a.is_active,
    a.pass_advance_days,
    a.default_currency_code,
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE 
    -- Superusers can see all authorities
    is_superuser()
    OR
    -- Country admins can see authorities in their countries
    (
      user_has_role('country_admin') AND
      a.country_id IN (
        SELECT DISTINCT pr.authority_id
        FROM profile_roles pr
        JOIN roles r ON r.id = pr.role_id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_admin'
        AND pr.is_active = true
      )
    )
  ORDER BY c.name, a.name;
$$;

-- Function: Check if authority code exists in a country
CREATE OR REPLACE FUNCTION authority_code_exists(
  target_country_id uuid,
  target_code text,
  exclude_authority_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if code exists in the specified country
  IF exclude_authority_id IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM authorities
      WHERE country_id = target_country_id
      AND UPPER(code) = UPPER(trim(target_code))
      AND id != exclude_authority_id
    );
  ELSE
    RETURN EXISTS (
      SELECT 1 FROM authorities
      WHERE country_id = target_country_id
      AND UPPER(code) = UPPER(trim(target_code))
    );
  END IF;
END;
$$;

-- Function: Get authority statistics
CREATE OR REPLACE FUNCTION get_authority_stats(target_authority_id uuid)
RETURNS TABLE (
  authority_id uuid,
  authority_name text,
  total_users integer,
  active_users integer,
  total_borders integer,
  active_borders integer,
  total_pass_templates integer,
  active_pass_templates integer,
  total_tax_rates integer,
  passes_issued_last_30_days integer
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    a.id as authority_id,
    a.name as authority_name,
    COALESCE(user_stats.total_users, 0) as total_users,
    COALESCE(user_stats.active_users, 0) as active_users,
    COALESCE(border_stats.total_borders, 0) as total_borders,
    COALESCE(border_stats.active_borders, 0) as active_borders,
    COALESCE(template_stats.total_pass_templates, 0) as total_pass_templates,
    COALESCE(template_stats.active_pass_templates, 0) as active_pass_templates,
    COALESCE(tax_stats.total_tax_rates, 0) as total_tax_rates,
    COALESCE(pass_stats.passes_issued_last_30_days, 0) as passes_issued_last_30_days
  FROM authorities a
  LEFT JOIN (
    SELECT 
      pr.authority_id,
      COUNT(*) as total_users,
      COUNT(CASE WHEN pr.is_active THEN 1 END) as active_users
    FROM profile_roles pr
    WHERE pr.authority_id = target_authority_id
    GROUP BY pr.authority_id
  ) user_stats ON user_stats.authority_id = a.id
  LEFT JOIN (
    SELECT 
      b.authority_id,
      COUNT(*) as total_borders,
      COUNT(CASE WHEN b.is_active THEN 1 END) as active_borders
    FROM borders b
    WHERE b.authority_id = target_authority_id
    GROUP BY b.authority_id
  ) border_stats ON border_stats.authority_id = a.id
  LEFT JOIN (
    SELECT 
      pt.authority_id,
      COUNT(*) as total_pass_templates,
      COUNT(CASE WHEN pt.is_active THEN 1 END) as active_pass_templates
    FROM pass_templates pt
    WHERE pt.authority_id = target_authority_id
    GROUP BY pt.authority_id
  ) template_stats ON template_stats.authority_id = a.id
  LEFT JOIN (
    SELECT 
      vtr.authority_id,
      COUNT(*) as total_tax_rates
    FROM vehicle_tax_rates vtr
    WHERE vtr.authority_id = target_authority_id
    GROUP BY vtr.authority_id
  ) tax_stats ON tax_stats.authority_id = a.id
  LEFT JOIN (
    SELECT 
      pt.authority_id,
      COUNT(*) as passes_issued_last_30_days
    FROM purchased_passes pp
    JOIN pass_templates pt ON pt.id = pp.pass_template_id
    WHERE pt.authority_id = target_authority_id
    AND pp.issued_at >= NOW() - INTERVAL '30 days'
    GROUP BY pt.authority_id
  ) pass_stats ON pass_stats.authority_id = a.id
  WHERE a.id = target_authority_id;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_all_authorities() TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_authorities() TO authenticated;
GRANT EXECUTE ON FUNCTION get_authorities_for_country(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_authorities() TO authenticated;
GRANT EXECUTE ON FUNCTION create_authority(uuid, text, text, text, text, integer, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION update_authority(uuid, text, text, text, text, integer, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_authority(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION authority_code_exists(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_authority_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_authority_types() TO authenticated;
