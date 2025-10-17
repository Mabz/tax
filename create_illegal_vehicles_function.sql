-- Create function to identify illegal vehicles in-country
-- These are vehicles that were scanned by local authority but show as "Departed" 
-- indicating they never properly checked in through border control

CREATE OR REPLACE FUNCTION get_illegal_vehicles_in_country(
  p_authority_id UUID DEFAULT NULL,
  p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
  pass_id UUID,
  vehicle_description TEXT,
  vehicle_registration_number TEXT,
  owner_name TEXT,
  last_scan_date TIMESTAMP WITH TIME ZONE,
  scan_location TEXT,
  scan_purpose TEXT,
  days_since_departure INTEGER,
  risk_level TEXT,
  current_status TEXT,
  vehicle_status_display TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH illegal_vehicles AS (
    SELECT DISTINCT
      pp.id as pass_id,
      pp.vehicle_description,
      pp.vehicle_registration_number,
      COALESCE(ap.full_name, ap.email, 'Unknown Owner') as owner_name,
      pm.processed_at as last_scan_date,
      COALESCE(pm.scan_location, 'Unknown Location') as scan_location,
      COALESCE(pm.scan_purpose, 'Unknown Purpose') as scan_purpose,
      CASE 
        WHEN pp.current_status = 'checked_out' THEN 
          EXTRACT(DAY FROM (pm.processed_at - (
            SELECT MAX(pm2.processed_at) 
            FROM pass_movements pm2 
            WHERE pm2.pass_id = pp.id 
            AND pm2.movement_type = 'check_out'
          )))::INTEGER
        ELSE 0
      END as days_since_departure,
      CASE 
        WHEN pm.processed_at > NOW() - INTERVAL '7 days' THEN 'HIGH'
        WHEN pm.processed_at > NOW() - INTERVAL '30 days' THEN 'MEDIUM'
        ELSE 'LOW'
      END as risk_level,
      pp.current_status,
      pp.vehicle_status_display
    FROM purchased_passes pp
    INNER JOIN pass_movements pm ON pp.id = pm.pass_id
    LEFT JOIN auth.users au ON pp.profile_id = au.id
    LEFT JOIN authority_profiles ap ON au.id = ap.profile_id
    WHERE 
      -- Filter by authority if specified
      (p_authority_id IS NULL OR pp.authority_id = p_authority_id)
      -- Only local authority scans
      AND pm.movement_type = 'local_authority_scan'
      -- Vehicle shows as departed but was found in country
      AND pp.vehicle_status_display = 'Departed'
      -- Within the specified time range
      AND pm.processed_at >= NOW() - (p_days_back || ' days')::INTERVAL
      -- Exclude test data
      AND NOT (pp.vehicle_description ILIKE '%test%' OR pp.vehicle_description ILIKE '%demo%')
  )
  SELECT 
    iv.pass_id,
    iv.vehicle_description,
    iv.vehicle_registration_number,
    iv.owner_name,
    iv.last_scan_date,
    iv.scan_location,
    iv.scan_purpose,
    iv.days_since_departure,
    iv.risk_level,
    iv.current_status,
    iv.vehicle_status_display
  FROM illegal_vehicles iv
  ORDER BY 
    iv.last_scan_date DESC,
    CASE iv.risk_level 
      WHEN 'HIGH' THEN 1 
      WHEN 'MEDIUM' THEN 2 
      ELSE 3 
    END;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_illegal_vehicles_in_country(UUID, INTEGER) TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION get_illegal_vehicles_in_country IS 
'Identifies vehicles that were scanned by local authority but show as departed, indicating potential illegal re-entry or border control bypass';