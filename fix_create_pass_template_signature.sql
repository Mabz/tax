-- Fix create_pass_template function to match Flutter service call
-- The Flutter service is calling with different parameter names

DROP FUNCTION IF EXISTS create_pass_template(uuid, uuid, uuid, text, integer, integer, numeric, text);

CREATE OR REPLACE FUNCTION create_pass_template(
  target_authority_id uuid,
  creator_profile_id uuid,
  vehicle_type_id uuid,
  description text,
  entry_limit integer,
  expiration_days integer,
  tax_amount numeric,
  currency_code text,
  target_border_id uuid DEFAULT NULL
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
    creator_profile_id,  -- Use the provided creator_profile_id instead of auth.uid()
    vehicle_type_id,     -- Use the provided vehicle_type_id
    description,
    entry_limit,
    expiration_days,
    tax_amount,
    currency_code
  );
END;
$$;

-- Also fix the update function to match the service call
DROP FUNCTION IF EXISTS update_pass_template(uuid, text, integer, integer, numeric, text, boolean);

CREATE OR REPLACE FUNCTION update_pass_template(
  template_id uuid,           -- Service calls it 'template_id', not 'target_template_id'
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
  WHERE id = template_id;  -- Use template_id instead of target_template_id
END;
$$;

-- Also fix the delete function to match the service call
DROP FUNCTION IF EXISTS delete_pass_template(uuid);

CREATE OR REPLACE FUNCTION delete_pass_template(
  template_id uuid           -- Service calls it 'template_id', not 'target_template_id'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM pass_templates WHERE id = template_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template(uuid, uuid, uuid, text, integer, integer, numeric, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template(uuid, text, integer, integer, numeric, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_pass_template(uuid) TO authenticated;

-- Verify the functions were created with correct signatures
SELECT 
  routine_name,
  routine_type,
  array_agg(parameter_name ORDER BY ordinal_position) as parameters
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE routine_name IN ('create_pass_template', 'update_pass_template', 'delete_pass_template')
AND routine_schema = 'public'
GROUP BY routine_name, routine_type
ORDER BY routine_name;