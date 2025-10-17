-- GPS Validation and Border Selection System
-- This implements the 30km validation rule and comprehensive audit logging

-- 1. Create function to calculate distance between two GPS coordinates (Haversine formula)
CREATE OR REPLACE FUNCTION calculate_distance_km(
    lat1 NUMERIC,
    lon1 NUMERIC,
    lat2 NUMERIC,
    lon2 NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    earth_radius CONSTANT NUMERIC := 6371; -- Earth's radius in kilometers
    dlat NUMERIC;
    dlon NUMERIC;
    a NUMERIC;
    c NUMERIC;
BEGIN
    -- Handle null coordinates
    IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Convert degrees to radians
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    
    -- Haversine formula
    a := sin(dlat/2) * sin(dlat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2) * sin(dlon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    
    -- Return distance in kilometers
    RETURN earth_radius * c;
END;
$$;

-- 2. Create function to get borders assigned to a border official
CREATE OR REPLACE FUNCTION get_official_assigned_borders(
    p_profile_id UUID
)
RETURNS TABLE (
    border_id UUID,
    border_name TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    can_check_in BOOLEAN,
    can_check_out BOOLEAN,
    distance_km NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_lat NUMERIC;
    v_current_lon NUMERIC;
BEGIN
    -- Get current GPS coordinates from the session or pass them as parameters
    -- For now, we'll return without distance calculation and let the app handle GPS
    
    RETURN QUERY
    SELECT 
        b.id as border_id,
        b.name as border_name,
        b.latitude,
        b.longitude,
        bob.can_check_in,
        bob.can_check_out,
        NULL::NUMERIC as distance_km -- Will be calculated in the app with current GPS
    FROM borders b
    JOIN border_official_borders bob ON b.id = bob.border_id
    WHERE bob.profile_id = p_profile_id
    AND bob.is_active = true
    AND b.is_active = true
    ORDER BY b.name;
END;
$$;

-- 3. Create function to validate GPS distance and log violations
CREATE OR REPLACE FUNCTION validate_border_gps_distance(
    p_pass_id UUID,
    p_border_id UUID,
    p_current_lat NUMERIC,
    p_current_lon NUMERIC,
    p_max_distance_km NUMERIC DEFAULT 30,
    p_performed_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_border_lat NUMERIC;
    v_border_lon NUMERIC;
    v_border_name TEXT;
    v_distance_km NUMERIC;
    v_is_within_range BOOLEAN;
    v_audit_id UUID;
    v_performed_by UUID;
    v_official_name TEXT;
BEGIN
    -- Get current user if not provided
    v_performed_by := COALESCE(p_performed_by, auth.uid());
    
    -- Get official name
    SELECT full_name INTO v_official_name
    FROM profiles 
    WHERE id = v_performed_by;
    
    -- Get border coordinates
    SELECT latitude, longitude, name 
    INTO v_border_lat, v_border_lon, v_border_name
    FROM borders 
    WHERE id = p_border_id;
    
    IF v_border_lat IS NULL OR v_border_lon IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Border coordinates not available',
            'border_name', v_border_name
        );
    END IF;
    
    -- Calculate distance
    v_distance_km := calculate_distance_km(
        p_current_lat, p_current_lon,
        v_border_lat, v_border_lon
    );
    
    -- Check if within acceptable range
    v_is_within_range := (v_distance_km IS NULL OR v_distance_km <= p_max_distance_km);
    
    -- Log the validation attempt in pass_processing_audit
    INSERT INTO pass_processing_audit (
        pass_id,
        action_type,
        performed_by,
        border_id,
        border_name,
        official_name,
        latitude,
        longitude,
        metadata
    ) VALUES (
        p_pass_id,
        CASE 
            WHEN v_is_within_range THEN 'gps_validation_passed'
            ELSE 'gps_validation_failed'
        END,
        v_performed_by,
        p_border_id,
        v_border_name,
        v_official_name,
        p_current_lat,
        p_current_lon,
        jsonb_build_object(
            'validation_type', 'gps_distance_check',
            'border_coordinates', jsonb_build_object(
                'latitude', v_border_lat,
                'longitude', v_border_lon
            ),
            'current_coordinates', jsonb_build_object(
                'latitude', p_current_lat,
                'longitude', p_current_lon
            ),
            'distance_km', v_distance_km,
            'max_allowed_km', p_max_distance_km,
            'within_range', v_is_within_range
        )
    ) RETURNING id INTO v_audit_id;
    
    -- Return validation result
    RETURN jsonb_build_object(
        'success', true,
        'within_range', v_is_within_range,
        'distance_km', v_distance_km,
        'max_allowed_km', p_max_distance_km,
        'border_name', v_border_name,
        'border_coordinates', jsonb_build_object(
            'latitude', v_border_lat,
            'longitude', v_border_lon
        ),
        'current_coordinates', jsonb_build_object(
            'latitude', p_current_lat,
            'longitude', p_current_lon
        ),
        'audit_id', v_audit_id
    );
END;
$$;

-- 4. Create function to log official's decision on distance violations
CREATE OR REPLACE FUNCTION log_distance_violation_response(
    p_audit_id UUID,
    p_official_decision TEXT, -- 'proceed' or 'cancel'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_performed_by UUID;
    v_pass_id UUID;
    v_border_id UUID;
    v_border_name TEXT;
    v_official_name TEXT;
BEGIN
    -- Get current user
    v_performed_by := auth.uid();
    
    -- Get details from the original audit record
    SELECT 
        pass_id, border_id, border_name, official_name
    INTO 
        v_pass_id, v_border_id, v_border_name, v_official_name
    FROM pass_processing_audit 
    WHERE id = p_audit_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Original audit record not found'
        );
    END IF;
    
    -- Update the original audit record with the decision
    UPDATE pass_processing_audit 
    SET 
        metadata = metadata || jsonb_build_object(
            'official_decision', p_official_decision,
            'decision_notes', p_notes,
            'decision_timestamp', NOW()
        ),
        updated_at = NOW()
    WHERE id = p_audit_id;
    
    -- Create a new audit record for the decision
    INSERT INTO pass_processing_audit (
        pass_id,
        action_type,
        performed_by,
        border_id,
        border_name,
        official_name,
        metadata
    ) VALUES (
        v_pass_id,
        CASE 
            WHEN p_official_decision = 'proceed' THEN 'distance_violation_proceed'
            ELSE 'distance_violation_cancel'
        END,
        v_performed_by,
        v_border_id,
        v_border_name,
        v_official_name,
        jsonb_build_object(
            'decision', p_official_decision,
            'notes', p_notes,
            'related_audit_id', p_audit_id
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'decision', p_official_decision,
        'audit_updated', true
    );
END;
$$;

-- 5. Create function to find nearest border from official's assigned borders
CREATE OR REPLACE FUNCTION find_nearest_assigned_border(
    p_profile_id UUID,
    p_current_lat NUMERIC,
    p_current_lon NUMERIC
)
RETURNS TABLE (
    border_id UUID,
    border_name TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    distance_km NUMERIC,
    can_check_in BOOLEAN,
    can_check_out BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id as border_id,
        b.name as border_name,
        b.latitude,
        b.longitude,
        calculate_distance_km(p_current_lat, p_current_lon, b.latitude, b.longitude) as distance_km,
        bob.can_check_in,
        bob.can_check_out
    FROM borders b
    JOIN border_official_borders bob ON b.id = bob.border_id
    WHERE bob.profile_id = p_profile_id
    AND bob.is_active = true
    AND b.is_active = true
    AND b.latitude IS NOT NULL
    AND b.longitude IS NOT NULL
    ORDER BY calculate_distance_km(p_current_lat, p_current_lon, b.latitude, b.longitude) ASC
    LIMIT 10; -- Return top 10 nearest borders
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_distance_km TO authenticated;
GRANT EXECUTE ON FUNCTION get_official_assigned_borders TO authenticated;
GRANT EXECUTE ON FUNCTION validate_border_gps_distance TO authenticated;
GRANT EXECUTE ON FUNCTION log_distance_violation_response TO authenticated;
GRANT EXECUTE ON FUNCTION find_nearest_assigned_border TO authenticated;

-- Add comments
COMMENT ON FUNCTION calculate_distance_km IS 'Calculates distance between two GPS coordinates using Haversine formula';
COMMENT ON FUNCTION get_official_assigned_borders IS 'Returns all borders assigned to a border official';
COMMENT ON FUNCTION validate_border_gps_distance IS 'Validates if current GPS is within acceptable range of border and logs the result';
COMMENT ON FUNCTION log_distance_violation_response IS 'Logs the official''s decision when GPS validation fails';
COMMENT ON FUNCTION find_nearest_assigned_border IS 'Finds the nearest border from official''s assigned borders based on GPS';

SELECT 'GPS validation system created successfully' as status;