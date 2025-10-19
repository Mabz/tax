-- Test function to verify vehicle updates work
-- This is a minimal version to test if RPC functions work at all

CREATE OR REPLACE FUNCTION test_update_vehicle(
  p_vehicle_id UUID,
  p_make TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Just try to update the make field
  UPDATE vehicles 
  SET make = p_make, updated_at = NOW()
  WHERE id = p_vehicle_id;

  -- Return success message
  IF FOUND THEN
    RETURN 'Vehicle updated successfully';
  ELSE
    RETURN 'Vehicle not found';
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION test_update_vehicle TO authenticated;