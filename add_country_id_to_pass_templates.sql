-- Add country_id to pass_templates table for easier querying
-- This allows direct country-based queries without needing to join through authorities

-- Step 1: Add the country_id column to pass_templates table
ALTER TABLE public.pass_templates 
ADD COLUMN country_id uuid;

-- Step 2: Populate the country_id column from the authority relationship
UPDATE public.pass_templates 
SET country_id = (
  SELECT a.country_id 
  FROM public.authorities a 
  WHERE a.id = pass_templates.authority_id
);

-- Step 3: Make country_id NOT NULL after population
ALTER TABLE public.pass_templates 
ALTER COLUMN country_id SET NOT NULL;

-- Step 4: Add foreign key constraint
ALTER TABLE public.pass_templates 
ADD CONSTRAINT pass_templates_country_id_fkey 
FOREIGN KEY (country_id) REFERENCES public.countries(id);

-- Step 5: Add index for better query performance
CREATE INDEX idx_pass_templates_country_id ON public.pass_templates(country_id);

-- Step 6: Update the create_pass_template function to include country_id
DROP FUNCTION IF EXISTS create_pass_template(uuid, uuid, uuid, text, integer, integer, numeric, text, uuid);

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
DECLARE
  target_country_id uuid;
BEGIN
  -- Get the country_id from the authority
  SELECT a.country_id INTO target_country_id
  FROM authorities a
  WHERE a.id = target_authority_id;
  
  IF target_country_id IS NULL THEN
    RAISE EXCEPTION 'Authority not found or invalid';
  END IF;
  
  INSERT INTO pass_templates (
    authority_id,
    country_id,
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
    target_country_id,
    target_border_id,
    creator_profile_id,
    vehicle_type_id,
    description,
    entry_limit,
    expiration_days,
    tax_amount,
    currency_code
  );
END;
$$;

-- Step 7: Create get_pass_templates_for_country function (now much simpler!)
CREATE OR REPLACE FUNCTION get_pass_templates_for_country(target_country_id uuid)
RETURNS TABLE (
  id uuid,
  authority_id uuid,
  country_id uuid,
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
    pt.country_id,
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
  JOIN countries c ON c.id = pt.country_id
  LEFT JOIN borders b ON b.id = pt.border_id
  JOIN vehicle_types vt ON vt.id = pt.vehicle_type_id
  WHERE pt.country_id = target_country_id
  ORDER BY pt.description;
$$;

-- Step 8: Update get_pass_templates_for_authority to include country_id in results
DROP FUNCTION IF EXISTS get_pass_templates_for_authority(uuid);

CREATE OR REPLACE FUNCTION get_pass_templates_for_authority(target_authority_id uuid)
RETURNS TABLE (
  id uuid,
  authority_id uuid,
  country_id uuid,
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
    pt.country_id,
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
  JOIN countries c ON c.id = pt.country_id
  LEFT JOIN borders b ON b.id = pt.border_id
  JOIN vehicle_types vt ON vt.id = pt.vehicle_type_id
  WHERE pt.authority_id = target_authority_id
  ORDER BY pt.description;
$$;

-- Step 9: Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template(uuid, uuid, uuid, text, integer, integer, numeric, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_templates_for_country(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority(uuid) TO authenticated;

-- Step 10: Verify the changes
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'pass_templates' 
AND column_name IN ('country_id', 'authority_id')
ORDER BY column_name;

-- Step 11: Verify the functions
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_name IN ('get_pass_templates_for_country', 'get_pass_templates_for_authority', 'create_pass_template')
AND routine_schema = 'public'
ORDER BY routine_name;