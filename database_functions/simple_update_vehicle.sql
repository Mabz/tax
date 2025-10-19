-- Simple function to update vehicle without restrictions
-- This function bypasses purchase pass constraints by using SECURITY DEFINER

CREATE OR REPLACE FUNCTION simple_update_vehicle(
  p_vehicle_id UUID,
  p_make TEXT,
  p_model TEXT,
  p_year INTEGER,
  p_color TEXT,
  p_vin TEXT,
  p_body_type TEXT DEFAULT NULL,
  p_fuel_type TEXT DEFAULT NULL,
  p_transmission TEXT DEFAULT NULL,
  p_engine_capacity DECIMAL DEFAULT NULL,
  p_registration_number TEXT DEFAULT NULL,
  p_country_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update the vehicle directly, bypassing RLS and constraints
  UPDATE vehicles 
  SET 
    make = p_make,
    model = p_model,
    year = p_year,
    color = p_color,
    vin = p_vin,
    body_type = p_body_type,
    fuel_type = p_fuel_type,
    transmission = p_transmission,
    engine_capacity = p_engine_capacity,
    registration_number = p_registration_number,
    country_of_registration_id = p_country_id,
    updated_at = NOW()
  WHERE id = p_vehicle_id;

  -- Also update purchased passes to maintain data consistency
  UPDATE purchased_passes 
  SET 
    vehicle_make = p_make,
    vehicle_model = p_model,
    vehicle_year = p_year,
    vehicle_color = p_color,
    vehicle_vin = p_vin,
    vehicle_registration_number = p_registration_number
  WHERE vehicle_id = p_vehicle_id;

  -- If no vehicle was found, raise an exception
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vehicle with ID % not found', p_vehicle_id;
  END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION simple_update_vehicle TO authenticated;