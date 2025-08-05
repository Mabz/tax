-- Alternative fix for vehicle tax rate functions without ON CONFLICT
-- Use this if the unique constraint cannot be added due to existing duplicates

-- Step 1: Fix the create_vehicle_tax_rate function without ON CONFLICT
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
DECLARE
  existing_count integer;
BEGIN
  -- Check if a tax rate already exists for this combination
  SELECT COUNT(*) INTO existing_count
  FROM vehicle_tax_rates
  WHERE authority_id = target_authority_id
    AND vehicle_type_id = target_vehicle_type_id
    AND (
      (border_id IS NULL AND target_border_id IS NULL) OR
      (border_id = target_border_id)
    );
  
  IF existing_count > 0 THEN
    -- Update existing record
    UPDATE vehicle_tax_rates 
    SET 
      tax_amount = create_vehicle_tax_rate.tax_amount,
      currency = create_vehicle_tax_rate.currency,
      updated_at = now()
    WHERE authority_id = target_authority_id
      AND vehicle_type_id = target_vehicle_type_id
      AND (
        (border_id IS NULL AND target_border_id IS NULL) OR
        (border_id = target_border_id)
      );
  ELSE
    -- Insert new record
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
    );
  END IF;
END;
$$;

-- Step 2: Fix the update_vehicle_tax_rate function
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

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION create_vehicle_tax_rate(uuid, uuid, numeric, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_vehicle_tax_rate(uuid, uuid, numeric, text, uuid) TO authenticated;

-- Step 4: Verify the functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_name IN ('create_vehicle_tax_rate', 'update_vehicle_tax_rate')
AND routine_schema = 'public';