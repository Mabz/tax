-- =====================================================
-- COMPLETE DATABASE FUNCTIONS FOR AUTHORITY MODEL
-- =====================================================

-- ========== AUTHORITY MANAGEMENT FUNCTIONS ==========

-- Function: Get all active authorities with country information
CREATE OR REPLACE FUNCTION get_active_authorities()
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
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
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE a.is_active = true AND c.is_active = true
  ORDER BY c.name, a.name;
$$;

-- Function: Get authorities for a specific country
CREATE OR REPLACE FUNCTION get_authorities_for_country(target_country_id uuid)
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
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
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE a.country_id = target_country_id AND a.is_active = true
  ORDER BY a.name;
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
  created_at timestamptz,
  updated_at timestamptz,
  country_name text,
  country_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT DISTINCT
    a.id,
    a.country_id,
    a.name,
    a.code,
    a.authority_type,
    a.description,
    a.is_active,
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN profile_roles pr ON pr.authority_id = a.id
  WHERE a.is_active = true 
    AND c.is_active = true
    AND (
      -- Superuser can see all authorities
      EXISTS (
        SELECT 1 FROM profile_roles pr2 
        JOIN roles r ON r.id = pr2.role_id 
        WHERE pr2.profile_id = auth.uid() 
          AND r.name = 'superuser' 
          AND pr2.is_active = true
      )
      OR
      -- Authority admin can see their authorities
      (pr.profile_id = auth.uid() AND pr.is_active = true)
    )
  ORDER BY c.name, a.name;
$$;

-- ========== PASS TEMPLATE FUNCTIONS ==========

-- Get pass templates for authority
CREATE OR REPLACE FUNCTION get_pass_templates_for_authority(target_authority_id uuid)
RETURNS TABLE (
  id uuid,
  authority_id uuid,
  border_id uuid,
  created_by_profile_id uuid,
  vehicle_type_id uuid,
  description text,
  entry_limit integer,
  expiration_days integer,
  tax_amount numeric,
  currency_code text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  authority_name text,
  country_name text,
  border_name text,
  vehicle_type text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    pt.id,
    pt.authority_id,
    pt.border_id,
    pt.created_by_profile_id,
    pt.vehicle_type_id,
    pt.description,
    pt.entry_limit,
    pt.expiration_days,
    pt.tax_amount,
    pt.currency_code,
    pt.is_active,
    pt.created_at,
    pt.updated_at,
    a.name as authority_name,
    c.name as country_name,
    b.name as border_name,
    vt.label as vehicle_type
  FROM pass_templates pt
  JOIN authorities a ON a.id = pt.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN borders b ON b.id = pt.border_id
  JOIN vehicle_types vt ON vt.id = pt.vehicle_type_id
  WHERE pt.authority_id = target_authority_id
  ORDER BY pt.description;
$$;

-- Create pass template
CREATE OR REPLACE FUNCTION create_pass_template(
  target_authority_id uuid,
  target_border_id uuid,
  target_vehicle_type_id uuid,
  template_description text,
  template_entry_limit integer,
  template_expiration_days integer,
  template_tax_amount numeric,
  template_currency_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO pass_templates (
    authority_id,
    border_id,
    created_by_profile_id,
    vehicle_type_id,
    description,
    entry_limit,
    expiration_days,
    tax_amount,
    currency_code
  ) VALUES (
    target_authority_id,
    target_border_id,
    auth.uid(),
    target_vehicle_type_id,
    template_description,
    template_entry_limit,
    template_expiration_days,
    template_tax_amount,
    template_currency_code
  );
END;
$$;

-- Update pass template
CREATE OR REPLACE FUNCTION update_pass_template(
  target_template_id uuid,
  new_description text,
  new_entry_limit integer,
  new_expiration_days integer,
  new_tax_amount numeric,
  new_currency_code text,
  new_is_active boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE pass_templates 
  SET 
    description = new_description,
    entry_limit = new_entry_limit,
    expiration_days = new_expiration_days,
    tax_amount = new_tax_amount,
    currency_code = new_currency_code,
    is_active = new_is_active,
    updated_at = now()
  WHERE id = target_template_id;
END;
$$;

-- Delete pass template
CREATE OR REPLACE FUNCTION delete_pass_template(target_template_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM pass_templates WHERE id = target_template_id;
END;
$$;

-- ========== BORDER FUNCTIONS ==========

-- Get borders for authority
CREATE OR REPLACE FUNCTION get_borders_for_authority(target_authority_id uuid)
RETURNS TABLE (
  border_id uuid,
  border_name text,
  border_type_id uuid,
  border_type_label text,
  authority_id uuid,
  authority_name text,
  country_name text,
  is_active boolean,
  latitude double precision,
  longitude double precision,
  description text,
  created_at timestamptz,
  updated_at timestamptz
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    b.id as border_id,
    b.name as border_name,
    b.border_type_id,
    bt.label as border_type_label,
    b.authority_id,
    a.name as authority_name,
    c.name as country_name,
    b.is_active,
    b.latitude,
    b.longitude,
    b.description,
    b.created_at,
    b.updated_at
  FROM borders b
  JOIN authorities a ON a.id = b.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN border_types bt ON bt.id = b.border_type_id
  WHERE b.authority_id = target_authority_id AND b.is_active = true
  ORDER BY b.name;
$$;

-- ========== VEHICLE TAX RATE FUNCTIONS ==========

-- Get vehicle tax rates for authority
CREATE OR REPLACE FUNCTION get_vehicle_tax_rates_for_authority(target_authority_id uuid)
RETURNS TABLE (
  id uuid,
  authority_name text,
  country_name text,
  border_name text,
  vehicle_type text,
  tax_amount numeric,
  currency text,
  created_at timestamptz,
  updated_at timestamptz
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    vtr.id,
    a.name as authority_name,
    c.name as country_name,
    b.name as border_name,
    vt.label as vehicle_type,
    vtr.tax_amount,
    vtr.currency,
    vtr.created_at,
    vtr.updated_at
  FROM vehicle_tax_rates vtr
  JOIN authorities a ON a.id = vtr.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN borders b ON b.id = vtr.border_id
  JOIN vehicle_types vt ON vt.id = vtr.vehicle_type_id
  WHERE vtr.authority_id = target_authority_id
  ORDER BY b.name NULLS FIRST, vt.label;
$$;

-- Create vehicle tax rate
CREATE OR REPLACE FUNCTION create_vehicle_tax_rate(
  target_authority_id uuid,
  target_vehicle_type_id uuid,
  tax_amount numeric,
  currency text,
  target_border_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO vehicle_tax_rates (
    authority_id,
    border_id,
    vehicle_type_id,
    tax_amount,
    currency
  ) VALUES (
    target_authority_id,
    target_border_id,
    target_vehicle_type_id,
    tax_amount,
    currency
  )
  ON CONFLICT (authority_id, COALESCE(border_id, '00000000-0000-0000-0000-000000000000'::uuid), vehicle_type_id)
  DO UPDATE SET
    tax_amount = EXCLUDED.tax_amount,
    currency = EXCLUDED.currency,
    updated_at = now();
END;
$$;

-- Update vehicle tax rate
CREATE OR REPLACE FUNCTION update_vehicle_tax_rate(
  target_authority_id uuid,
  target_vehicle_type_id uuid,
  new_tax_amount numeric,
  new_currency text,
  target_border_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE vehicle_tax_rates 
  SET 
    tax_amount = new_tax_amount,
    currency = new_currency,
    updated_at = now()
  WHERE authority_id = target_authority_id
    AND vehicle_type_id = target_vehicle_type_id
    AND border_id IS NOT DISTINCT FROM target_border_id;
END;
$$;

-- Delete vehicle tax rate
CREATE OR REPLACE FUNCTION delete_vehicle_tax_rate(
  target_authority_id uuid,
  target_vehicle_type_id uuid,
  target_border_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM vehicle_tax_rates 
  WHERE authority_id = target_authority_id
    AND vehicle_type_id = target_vehicle_type_id
    AND border_id IS NOT DISTINCT FROM target_border_id;
END;
$$;

-- ========== USER MANAGEMENT FUNCTIONS ==========

-- Get profiles by authority
CREATE OR REPLACE FUNCTION get_profiles_by_authority(target_authority_id uuid)
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
  WHERE pr.authority_id = target_authority_id
  GROUP BY p.id, p.full_name, p.email
  ORDER BY p.full_name;
$$;

-- Get all invitations for authority
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

-- ========== UTILITY FUNCTIONS ==========

-- Get vehicle types
CREATE OR REPLACE FUNCTION get_vehicle_types()
RETURNS TABLE (
  id uuid,
  code text,
  label text,
  description text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id, code, label, description
  FROM vehicle_types
  ORDER BY label;
$$;

-- Get active currencies
CREATE OR REPLACE FUNCTION get_active_currencies()
RETURNS TABLE (
  code text,
  name text,
  symbol text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT code, name, symbol
  FROM currencies
  WHERE is_active = true
  ORDER BY name;
$$;

-- Get all countries for selection
CREATE OR REPLACE FUNCTION get_all_countries_for_selection()
RETURNS TABLE (
  id uuid,
  name text,
  country_code text,
  is_active boolean
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id, name, country_code, is_active
  FROM countries
  ORDER BY name;
$$;

-- ========== PASS FUNCTIONS ==========

-- Issue pass from template
CREATE OR REPLACE FUNCTION issue_pass_from_template(
  target_profile_id uuid,
  target_vehicle_id uuid,
  pass_template_id uuid,
  pass_hash text,
  short_code text,
  qr_data jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_pass_id uuid;
  template_record record;
BEGIN
  -- Get template details
  SELECT pt.*, a.country_id
  INTO template_record
  FROM pass_templates pt
  JOIN authorities a ON a.id = pt.authority_id
  WHERE pt.id = pass_template_id;

  -- Insert the new pass
  INSERT INTO purchased_passes (
    profile_id,
    vehicle_id,
    pass_template_id,
    expires_at,
    entries_remaining,
    pass_hash,
    short_code,
    qr_data
  ) VALUES (
    target_profile_id,
    target_vehicle_id,
    pass_template_id,
    now() + (template_record.expiration_days || ' days')::interval,
    template_record.entry_limit,
    pass_hash,
    short_code,
    qr_data
  ) RETURNING id INTO new_pass_id;

  RETURN new_pass_id;
END;
$$;

-- Get passes for user
CREATE OR REPLACE FUNCTION get_passes_for_user(target_profile_id uuid)
RETURNS TABLE (
  pass_id uuid,
  pass_description text,
  vehicle_description text,
  border_name text,
  authority_name text,
  country_name text,
  vehicle_type text,
  issued_at timestamptz,
  expires_at timestamptz,
  entries_remaining integer,
  entry_limit integer,
  status text,
  amount numeric,
  currency text,
  qr_code text,
  short_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    pp.id as pass_id,
    pt.description as pass_description,
    v.description as vehicle_description,
    b.name as border_name,
    a.name as authority_name,
    c.name as country_name,
    vt.label as vehicle_type,
    pp.issued_at,
    pp.expires_at,
    pp.entries_remaining,
    pt.entry_limit,
    pp.status,
    pt.tax_amount as amount,
    pt.currency_code as currency,
    pp.qr_data::text as qr_code,
    pp.short_code
  FROM purchased_passes pp
  JOIN pass_templates pt ON pt.id = pp.pass_template_id
  JOIN authorities a ON a.id = pt.authority_id
  JOIN countries c ON c.id = a.country_id
  LEFT JOIN borders b ON b.id = pt.border_id
  JOIN vehicles v ON v.id = pp.vehicle_id
  JOIN vehicle_types vt ON vt.id = pt.vehicle_type_id
  WHERE pp.profile_id = target_profile_id
  ORDER BY pp.issued_at DESC;
$$;
