-- Fix vehicle tax rate constraints and functions
-- The issue is that ON CONFLICT is used without proper unique constraints

-- Step 1: Add a simpler unique constraint (without COALESCE)
-- We'll handle NULL border_id cases in the application logic instead
ALTER TABLE public.vehicle_tax_rates 
ADD CONSTRAINT vehicle_tax_rates_unique_assignment 
UNIQUE (authority_id, vehicle_type_id, border_id);

-- Step 2: Fix the create_vehicle_tax_rate function
DROP FUNCTION IF EXISTS create_vehicle_tax_rate(uuid, uuid, numeric, text, uuid);

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
  ON CONFLICT (authority_id, vehicle_type_id, border_id)
  DO UPDATE SET
    tax_amount = EXCLUDED.tax_amount,
    currency = EXCLUDED.currency,
    updated_at = now();
END;
$$;

-- Step 3: Fix the update_vehicle_tax_rate function to handle cases where record doesn't exist
DROP FUNCTION IF EXISTS update_vehicle_tax_rate(uuid, uuid, numeric, text, uuid);

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
DECLARE
  updated_rows integer;
BEGIN
  -- Try to update existing record
  UPDATE vehicle_tax_rates 
  SET 
    tax_amount = new_tax_amount,
    currency = new_currency,
    updated_at = now()
  WHERE authority_id = target_authority_id
    AND vehicle_type_id = target_vehicle_type_id
    AND (
      (border_id IS NULL AND target_border_id IS NULL) OR
      (border_id = target_border_id)
    );
  
  GET DIAGNOSTICS updated_rows = ROW_COUNT;
  
  -- If no rows were updated, insert a new record
  IF updated_rows = 0 THEN
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
      new_tax_amount,
      new_currency
    );
  END IF;
END;
$$;

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION create_vehicle_tax_rate(uuid, uuid, numeric, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_vehicle_tax_rate(uuid, uuid, numeric, text, uuid) TO authenticated;

-- Step 5: Test the constraint
SELECT 
  constraint_name,
  constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'vehicle_tax_rates' 
AND constraint_type = 'UNIQUE';

-- Step 6: Verify the functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_name IN ('create_vehicle_tax_rate', 'update_vehicle_tax_rate')
AND routine_schema = 'public';