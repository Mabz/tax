-- Fix vehicle functions to match Dart service calls
-- The issue is parameter name mismatches between Dart and SQL

-- Fix get_vehicles_for_user function to accept target_profile_id parameter
DROP FUNCTION IF EXISTS get_vehicles_for_user(uuid);

CREATE OR REPLACE FUNCTION get_vehicles_for_user(target_profile_id uuid DEFAULT NULL)
RETURNS TABLE (
  vehicle_id uuid,
  profile_id uuid,
  number_plate text,
  description text,
  vin_number text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    v.id as vehicle_id,
    v.profile_id,
    v.number_plate,
    v.description,
    v.vin_number,
    v.created_at,
    v.updated_at
  FROM vehicles v
  WHERE v.profile_id = COALESCE(target_profile_id, auth.uid())
  ORDER BY v.created_at DESC;
$$;

-- Create create_vehicle function if it doesn't exist
CREATE OR REPLACE FUNCTION create_vehicle(
  target_profile_id uuid,
  number_plate text,
  description text,
  vin_number text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO vehicles (
    profile_id,
    number_plate,
    description,
    vin_number
  ) VALUES (
    target_profile_id,
    number_plate,
    description,
    vin_number
  );
END;
$$;

-- Create update_vehicle function if it doesn't exist
CREATE OR REPLACE FUNCTION update_vehicle(
  vehicle_id uuid,
  new_number_plate text,
  new_description text,
  new_vin_number text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE vehicles 
  SET 
    number_plate = new_number_plate,
    description = new_description,
    vin_number = new_vin_number,
    updated_at = now()
  WHERE id = vehicle_id
  AND profile_id = auth.uid(); -- Security: only update own vehicles
END;
$$;

-- Create delete_vehicle function if it doesn't exist
CREATE OR REPLACE FUNCTION delete_vehicle(vehicle_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM vehicles 
  WHERE id = vehicle_id
  AND profile_id = auth.uid(); -- Security: only delete own vehicles
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_vehicles_for_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_vehicle(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_vehicle(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_vehicle(uuid) TO authenticated;

-- Verify the functions were created
SELECT 
  routine_name,
  routine_type,
  array_agg(parameter_name ORDER BY ordinal_position) as parameters
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE routine_name IN ('get_vehicles_for_user', 'create_vehicle', 'update_vehicle', 'delete_vehicle')
AND routine_schema = 'public'
GROUP BY routine_name, routine_type
ORDER BY routine_name;