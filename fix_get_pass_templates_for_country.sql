-- Create missing get_pass_templates_for_country function
-- This is a bridge function that converts country_id to authority_id

CREATE OR REPLACE FUNCTION get_pass_templates_for_country(target_country_id uuid)
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
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_authority_id uuid;
BEGIN
  -- Find the authority for this country
  SELECT a.id INTO target_authority_id
  FROM authorities a
  WHERE a.country_id = target_country_id
  AND a.is_active = true
  LIMIT 1;
  
  -- If no authority found, return empty result
  IF target_authority_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Return results from the authority-based function
  RETURN QUERY
  SELECT * FROM get_pass_templates_for_authority(target_authority_id);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_pass_templates_for_country(uuid) TO authenticated;

-- Verify the function was created
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines 
WHERE routine_name = 'get_pass_templates_for_country'
AND routine_schema = 'public';