-- Function to search vehicles by VIN, make, model, or registration number for a specific border
-- This function aggregates vehicle movements and provides search capabilities

CREATE OR REPLACE FUNCTION search_border_vehicles(
    border_id_param UUID,
    search_query TEXT,
    result_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    vehicle_registration_number TEXT,
    vehicle_vin TEXT,
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_year INTEGER,
    vehicle_color TEXT,
    vehicle_description TEXT,
    total_movements BIGINT,
    last_movement TIMESTAMP WITH TIME ZONE,
    last_movement_type TEXT,
    pass_ids TEXT[]
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH vehicle_movements AS (
        SELECT 
            pp.vehicle_registration_number,
            pp.vehicle_vin,
            pp.vehicle_make,
            pp.vehicle_model,
            pp.vehicle_year,
            pp.vehicle_color,
            pp.vehicle_description,
            pm.movement_type,
            pm.timestamp,
            pp.pass_id
        FROM pass_movements pm
        INNER JOIN purchased_passes pp ON pm.pass_id = pp.pass_id
        WHERE pm.border_id = border_id_param
        AND (
            LOWER(pp.vehicle_vin) LIKE '%' || LOWER(search_query) || '%'
            OR LOWER(pp.vehicle_make) LIKE '%' || LOWER(search_query) || '%'
            OR LOWER(pp.vehicle_model) LIKE '%' || LOWER(search_query) || '%'
            OR LOWER(pp.vehicle_registration_number) LIKE '%' || LOWER(search_query) || '%'
            OR LOWER(pp.vehicle_description) LIKE '%' || LOWER(search_query) || '%'
        )
    ),
    vehicle_groups AS (
        SELECT 
            COALESCE(vm.vehicle_vin, vm.vehicle_registration_number, 
                     vm.vehicle_make || '-' || vm.vehicle_model || '-' || vm.vehicle_year::TEXT) as vehicle_key,
            vm.vehicle_registration_number,
            vm.vehicle_vin,
            vm.vehicle_make,
            vm.vehicle_model,
            vm.vehicle_year,
            vm.vehicle_color,
            vm.vehicle_description,
            COUNT(*) as total_movements,
            MAX(vm.timestamp) as last_movement,
            (ARRAY_AGG(vm.movement_type ORDER BY vm.timestamp DESC))[1] as last_movement_type,
            ARRAY_AGG(DISTINCT vm.pass_id) as pass_ids
        FROM vehicle_movements vm
        GROUP BY 
            vehicle_key,
            vm.vehicle_registration_number,
            vm.vehicle_vin,
            vm.vehicle_make,
            vm.vehicle_model,
            vm.vehicle_year,
            vm.vehicle_color,
            vm.vehicle_description
        ORDER BY last_movement DESC
        LIMIT result_limit
    )
    SELECT 
        vg.vehicle_registration_number,
        vg.vehicle_vin,
        vg.vehicle_make,
        vg.vehicle_model,
        vg.vehicle_year,
        vg.vehicle_color,
        vg.vehicle_description,
        vg.total_movements,
        vg.last_movement,
        vg.last_movement_type,
        vg.pass_ids
    FROM vehicle_groups vg;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION search_border_vehicles(UUID, TEXT, INTEGER) TO authenticated;

-- Example usage:
-- SELECT * FROM search_border_vehicles('border-uuid-here', 'toyota', 10);
-- SELECT * FROM search_border_vehicles('border-uuid-here', 'ABC123', 20);