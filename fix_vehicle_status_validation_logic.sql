-- Fix Vehicle Status Validation Logic
-- This addresses the issue where a "departed" vehicle shows as "LEGAL" when scanned in-country

-- Create enhanced pass validation function that checks logical consistency
CREATE OR REPLACE FUNCTION validate_pass_with_location_logic(
    p_pass_id UUID,
    p_scan_context TEXT DEFAULT 'local_authority' -- 'local_authority' or 'border_control'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass_record RECORD;
    v_latest_movement RECORD;
    v_vehicle_location_status TEXT;
    v_is_legal BOOLEAN := false;
    v_violation_reason TEXT;
    v_result JSONB;
BEGIN
    -- Get pass details
    SELECT * INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass not found'
        );
    END IF;

    -- Get the latest movement to determine actual vehicle location status
    SELECT 
        movement_type,
        new_status,
        processed_at,
        border_id
    INTO v_latest_movement
    FROM pass_movements
    WHERE pass_id = p_pass_id
    ORDER BY processed_at DESC
    LIMIT 1;

    -- Determine vehicle location status based on latest movement
    IF v_latest_movement.movement_type = 'check_out' THEN
        v_vehicle_location_status := 'departed';
    ELSIF v_latest_movement.movement_type = 'check_in' THEN
        v_vehicle_location_status := 'in_country';
    ELSIF v_pass_record.current_status IN ('active', 'unused') THEN
        v_vehicle_location_status := 'in_country'; -- Default for active passes
    ELSE
        v_vehicle_location_status := 'unknown';
    END IF;

    -- Enhanced validation logic
    IF p_scan_context = 'local_authority' THEN
        -- For local authority scans, vehicle must be physically in the country
        IF v_vehicle_location_status = 'departed' THEN
            v_is_legal := false;
            v_violation_reason := 'Vehicle shows as departed but found in country - possible illegal re-entry or data error';
            
        ELSIF v_pass_record.status = 'expired' THEN
            v_is_legal := false;
            v_violation_reason := 'Pass has expired';
            
        ELSIF v_pass_record.entries_remaining <= 0 THEN
            v_is_legal := false;
            v_violation_reason := 'No entries remaining on pass';
            
        ELSIF v_pass_record.expires_at < NOW() THEN
            v_is_legal := false;
            v_violation_reason := 'Pass validity period has expired';
            
        ELSIF v_pass_record.status = 'cancelled' THEN
            v_is_legal := false;
            v_violation_reason := 'Pass has been cancelled';
            
        ELSE
            v_is_legal := true;
            v_violation_reason := null;
        END IF;
        
    ELSE
        -- For border control, different logic applies
        v_is_legal := (v_pass_record.status = 'active' AND v_pass_record.expires_at > NOW());
        IF NOT v_is_legal THEN
            v_violation_reason := 'Pass not valid for border processing';
        END IF;
    END IF;

    -- Build comprehensive result
    v_result := jsonb_build_object(
        'success', true,
        'is_legal', v_is_legal,
        'violation_reason', v_violation_reason,
        'vehicle_location_status', v_vehicle_location_status,
        'pass_status', v_pass_record.current_status,
        'entries_remaining', v_pass_record.entries_remaining,
        'expires_at', v_pass_record.expires_at,
        'latest_movement', CASE 
            WHEN v_latest_movement IS NOT NULL THEN
                jsonb_build_object(
                    'type', v_latest_movement.movement_type,
                    'status', v_latest_movement.new_status,
                    'processed_at', v_latest_movement.processed_at
                )
            ELSE null
        END,
        'scan_context', p_scan_context,
        'validation_timestamp', NOW()
    );

    RETURN v_result;
END;
$$;

-- Create a simpler wrapper function for the existing verify_pass calls
CREATE OR REPLACE FUNCTION verify_pass_enhanced(
    verification_code TEXT,
    is_qr_code BOOLEAN DEFAULT true,
    scan_context TEXT DEFAULT 'local_authority'
)
RETURNS TABLE (
    id UUID,
    profile_id UUID,
    vehicle_description TEXT,
    pass_description TEXT,
    current_status TEXT,
    entries_remaining INTEGER,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_legal BOOLEAN,
    violation_reason TEXT,
    vehicle_location_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass_id UUID;
    v_validation_result JSONB;
BEGIN
    -- First, find the pass using existing logic
    IF is_qr_code THEN
        -- Extract pass ID from QR code JSON
        BEGIN
            SELECT (verification_code::jsonb->>'id')::UUID INTO v_pass_id;
        EXCEPTION WHEN OTHERS THEN
            -- Try direct UUID parsing
            BEGIN
                v_pass_id := verification_code::UUID;
            EXCEPTION WHEN OTHERS THEN
                RETURN; -- Invalid format
            END;
        END;
    ELSE
        -- Look up by backup code
        SELECT pp.id INTO v_pass_id
        FROM purchased_passes pp
        WHERE pp.short_code = verification_code;
    END IF;

    IF v_pass_id IS NULL THEN
        RETURN; -- Pass not found
    END IF;

    -- Get enhanced validation
    SELECT validate_pass_with_location_logic(v_pass_id, scan_context) INTO v_validation_result;

    -- Return the pass data with validation results
    RETURN QUERY
    SELECT 
        pp.id,
        pp.profile_id,
        pp.vehicle_description,
        pp.pass_description,
        pp.current_status,
        pp.entries_remaining,
        pp.expires_at,
        (v_validation_result->>'is_legal')::BOOLEAN as is_legal,
        v_validation_result->>'violation_reason' as violation_reason,
        v_validation_result->>'vehicle_location_status' as vehicle_location_status
    FROM purchased_passes pp
    WHERE pp.id = v_pass_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION validate_pass_with_location_logic TO authenticated;
GRANT EXECUTE ON FUNCTION verify_pass_enhanced TO authenticated;

-- Add comments
COMMENT ON FUNCTION validate_pass_with_location_logic IS 'Enhanced pass validation that checks logical consistency between pass status and vehicle location';
COMMENT ON FUNCTION verify_pass_enhanced IS 'Enhanced pass verification with location-aware validation logic';

-- Test the function with a sample pass
SELECT '✅ Enhanced validation functions created' as status;
SELECT 'Use verify_pass_enhanced() instead of verify_pass() for location-aware validation' as usage;