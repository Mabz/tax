-- Enhanced Border Processing with GPS Validation
-- This replaces the existing process_pass_movement function with GPS validation logic

-- Drop existing function versions
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, TEXT);
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, JSONB);

-- Create enhanced process_pass_movement function with GPS validation
CREATE OR REPLACE FUNCTION process_pass_movement_with_gps_validation(
    p_pass_id UUID,
    p_border_id UUID,
    p_current_lat NUMERIC,
    p_current_lon NUMERIC,
    p_gps_validation_override BOOLEAN DEFAULT false,
    p_override_reason TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_movement_id UUID;
    v_current_user_id UUID;
    v_pass_record RECORD;
    v_movement_type TEXT;
    v_previous_status TEXT;
    v_new_status TEXT;
    v_entries_to_deduct INTEGER := 0;
    v_gps_validation JSONB;
    v_border_name TEXT;
    v_official_name TEXT;
    v_audit_id UUID;
    v_result JSONB;
BEGIN
    -- Get current user (border official)
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not authenticated'
        );
    END IF;

    -- Get official name
    SELECT full_name INTO v_official_name
    FROM profiles 
    WHERE id = v_current_user_id;

    -- Get border name
    SELECT name INTO v_border_name
    FROM borders 
    WHERE id = p_border_id;

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

    -- Validate GPS distance unless override is specified
    IF NOT p_gps_validation_override THEN
        v_gps_validation := validate_border_gps_distance(
            p_pass_id,
            p_border_id,
            p_current_lat,
            p_current_lon,
            30 -- 30km default range
        );
        
        -- If GPS validation failed, return the validation result for UI handling
        IF NOT (v_gps_validation->>'within_range')::BOOLEAN THEN
            RETURN jsonb_build_object(
                'success', false,
                'error_type', 'gps_validation_failed',
                'gps_validation', v_gps_validation,
                'requires_override', true
            );
        END IF;
    ELSE
        -- Log the override decision
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
            'gps_validation_override',
            v_current_user_id,
            p_border_id,
            v_border_name,
            v_official_name,
            p_current_lat,
            p_current_lon,
            jsonb_build_object(
                'override_reason', p_override_reason,
                'validation_bypassed', true
            )
        );
    END IF;

    -- Determine movement type based on current status
    IF v_pass_record.current_status = 'active' OR v_pass_record.current_status = 'unused' THEN
        v_movement_type := 'check_in';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'in_transit';
        v_entries_to_deduct := 1;
        
    ELSIF v_pass_record.current_status = 'in_transit' THEN
        v_movement_type := 'check_out';
        v_previous_status := 'in_transit';
        v_new_status := 'active';
        v_entries_to_deduct := 0; -- No additional deduction for check-out
        
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass status does not allow movement processing'
        );
    END IF;

    -- Check if pass has enough entries for check-in
    IF v_movement_type = 'check_in' AND v_pass_record.entries_remaining < v_entries_to_deduct THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient entries remaining'
        );
    END IF;

    -- Enhance metadata with movement and GPS information
    p_metadata := p_metadata || jsonb_build_object(
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'processed_by', v_current_user_id,
        'processed_at', NOW(),
        'gps_coordinates', jsonb_build_object(
            'latitude', p_current_lat,
            'longitude', p_current_lon
        ),
        'gps_validation_override', p_gps_validation_override,
        'override_reason', p_override_reason
    );

    -- Record the movement in pass_movements
    INSERT INTO pass_movements (
        pass_id,
        border_id,
        profile_id,
        movement_type,
        previous_status,
        new_status,
        entries_deducted,
        latitude,
        longitude,
        authority_type,
        metadata,
        processed_at
    ) VALUES (
        p_pass_id,
        p_border_id,
        v_current_user_id,
        v_movement_type,
        v_previous_status,
        v_new_status,
        v_entries_to_deduct,
        p_current_lat,
        p_current_lon,
        'border_official',
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;

    -- Update pass status and entries
    UPDATE purchased_passes 
    SET 
        current_status = v_new_status,
        entries_remaining = entries_remaining - v_entries_to_deduct,
        updated_at = NOW()
    WHERE id = p_pass_id;

    -- Log successful processing in audit table
    INSERT INTO pass_processing_audit (
        pass_id,
        action_type,
        performed_by,
        previous_status,
        new_status,
        entries_deducted,
        entries_remaining,
        border_id,
        border_name,
        official_name,
        latitude,
        longitude,
        metadata
    ) VALUES (
        p_pass_id,
        v_movement_type || '_completed',
        v_current_user_id,
        v_previous_status,
        v_new_status,
        v_entries_to_deduct,
        v_pass_record.entries_remaining - v_entries_to_deduct,
        p_border_id,
        v_border_name,
        v_official_name,
        p_current_lat,
        p_current_lon,
        p_metadata || jsonb_build_object(
            'movement_id', v_movement_id,
            'processing_completed', true
        )
    ) RETURNING id INTO v_audit_id;

    -- Get updated pass data
    SELECT * INTO v_pass_record FROM purchased_passes WHERE id = p_pass_id;

    -- Return success with updated data
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'audit_id', v_audit_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_remaining', v_pass_record.entries_remaining,
        'gps_validation', COALESCE(v_gps_validation, jsonb_build_object('status', 'overridden')),
        'pass_data', to_jsonb(v_pass_record)
    );

    RETURN v_result;
END;
$$;

-- Create wrapper function for backward compatibility (without GPS validation)
CREATE OR REPLACE FUNCTION process_pass_movement(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Call the enhanced function with GPS validation override
    RETURN process_pass_movement_with_gps_validation(
        p_pass_id,
        p_border_id,
        p_latitude,
        p_longitude,
        true, -- Override GPS validation for backward compatibility
        'legacy_function_call',
        p_metadata
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement_with_gps_validation TO authenticated;
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- Add comments
COMMENT ON FUNCTION process_pass_movement_with_gps_validation IS 'Enhanced pass movement processing with GPS validation and comprehensive audit logging';
COMMENT ON FUNCTION process_pass_movement IS 'Backward compatible wrapper for pass movement processing';

SELECT 'Enhanced border processing functions created successfully' as status;