-- Fix missing pass template functions
-- These functions are needed for pass template management

-- Function 1: Get pass templates for authority
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

-- Function 2: Create pass template
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

-- Function 3: Update pass template
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

-- Function 4: Delete pass template
CREATE OR REPLACE FUNCTION delete_pass_template(target_template_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM pass_templates WHERE id = target_template_id;
END;
$$;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_pass_template(uuid, uuid, uuid, text, integer, integer, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template(uuid, text, integer, integer, numeric, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_pass_template(uuid) TO authenticated;

-- Verify the functions were created
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines 
WHERE routine_name IN (
  'get_pass_templates_for_authority',
  'create_pass_template', 
  'update_pass_template',
  'delete_pass_template'
)
AND routine_schema = 'public'
ORDER BY routine_name;