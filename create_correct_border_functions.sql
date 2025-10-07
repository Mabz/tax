-- Create Correct Border Control Functions
-- Clean implementation with proper status flow: unused -> checked_in -> checked_out
-- No migration needed - fresh start

-- ============================================================================
-- MAIN FUNCTION: process_pass_movement (with metadata)
-- ============================================================================
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
DECLARE
    v_movement_id UUID;
    v_current_user_id UUID;
    v_pass_record RECORD;
    v_movement_type TEXT;
    v_previous_status TEXT;
    v_new_status TEXT;
    v_entries_to_deduct INTEGER := 0;
    v_result JSONB;
BEGIN
    -- Get current user (border official)
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not authenticated',
            'message', 'User not authenticated',
            'movement_type', '',
            'previous_status', '',
            'new_status', '',
            'entries_deducted', 0,
            'entries_remaining', 0
        );
    END IF;

    -- Get pass details
    SELECT * INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass not found',
            'message', 'Pass not found',
            'movement_type', '',
            'previous_status', '',
            'new_status', '',
            'entries_deducted', 0,
            'entries_remaining', 0
        );
    END IF;

    -- Determine movement type based on current status
    -- Status flow: unused -> checked_in -> checked_out -> checked_in (repeat)
    IF v_pass_record.current_status = 'unused' OR v_pass_record.current_status IS NULL THEN
        -- First entry into country
        v_movement_type := 'check_in';
        v_previous_status := COALESCE(v_pass_record.current_status, 'unused');
        v_new_status := 'checked_in';
        v_entries_to_deduct := 1;
        
    ELSIF v_pass_record.current_status = 'checked_in' THEN
        -- Exiting country
        v_movement_type := 'check_out';
        v_previous_status := 'checked_in';
        v_new_status := 'checked_out';
        v_entries_to_deduct := 0; -- No additional deduction for check-out
        
    ELSIF v_pass_record.current_status = 'checked_out' THEN
        -- Re-entering country after previous exit
        v_movement_type := 'check_in';
        v_previous_status := 'checked_out';
        v_new_status := 'checked_in';
        v_entries_to_deduct := 1;
        
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass status does not allow movement processing',
            'message', format('Pass status "%s" does not allow movement processing', COALESCE(v_pass_record.current_status, 'unknown')),
            'current_status', COALESCE(v_pass_record.current_status, 'unknown'),
            'movement_type', '',
            'previous_status', '',
            'new_status', '',
            'entries_deducted', 0,
            'entries_remaining', COALESCE(v_pass_record.entries_remaining, 0)
        );
    END IF;

    -- Check if pass has enough entries for check-in
    IF v_movement_type = 'check_in' AND v_pass_record.entries_remaining < v_entries_to_deduct THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient entries remaining',
            'message', format('Insufficient entries remaining: %s available, %s required', 
                            COALESCE(v_pass_record.entries_remaining, 0), v_entries_to_deduct),
            'movement_type', v_movement_type,
            'previous_status', COALESCE(v_previous_status, ''),
            'new_status', '',
            'entries_deducted', 0,
            'entries_remaining', COALESCE(v_pass_record.entries_remaining, 0)
        );
    END IF;

    -- Enhance metadata with movement information
    p_metadata := p_metadata || jsonb_build_object(
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'processed_by', v_current_user_id,
        'processed_at', NOW()
    );

    -- Record the movement
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
        p_latitude,
        p_longitude,
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

    -- Get updated pass data
    SELECT * INTO v_pass_record FROM purchased_passes WHERE id = p_pass_id;

    -- Return success with updated data
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', COALESCE(v_movement_id::text, ''),
        'movement_type', COALESCE(v_movement_type, ''),
        'previous_status', COALESCE(v_previous_status, ''),
        'new_status', COALESCE(v_new_status, ''),
        'entries_deducted', COALESCE(v_entries_to_deduct, 0),
        'entries_remaining', COALESCE(v_pass_record.entries_remaining, 0),
        'border_id', COALESCE(p_border_id::text, ''),
        'pass_id', COALESCE(p_pass_id::text, ''),
        'message', format('Pass %s successful', v_movement_type),
        'pass_data', to_jsonb(v_pass_record)
    );

    RETURN v_result;
END;
$$;

-- ============================================================================
-- OVERLOAD: process_pass_movement (with notes parameter)
-- ============================================================================
CREATE OR REPLACE FUNCTION process_pass_movement(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Call the main function with notes converted to metadata
    RETURN process_pass_movement(
        p_pass_id,
        p_border_id,
        p_latitude,
        p_longitude,
        jsonb_build_object('notes', p_notes)
    );
END;
$$;

-- ============================================================================
-- Grant permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, TEXT) TO authenticated;

-- ============================================================================
-- Add documentation
-- ============================================================================
COMMENT ON FUNCTION process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, JSONB) IS 
'Processes pass movements at border control. Status flow: unused -> checked_in -> checked_out -> checked_in (repeat). Deducts entry on check-in only.';

COMMENT ON FUNCTION process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, TEXT) IS 
'Convenience wrapper for process_pass_movement that accepts notes as TEXT instead of JSONB metadata.';

-- ============================================================================
-- Verification
-- ============================================================================
DO $$
DECLARE
    function_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO function_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'process_pass_movement'
    AND n.nspname = 'public';
    
    RAISE NOTICE '✅ Border control functions created successfully!';
    RAISE NOTICE '   - % versions of process_pass_movement function created', function_count;
    RAISE NOTICE '   - Status flow: unused -> checked_in -> checked_out';
    RAISE NOTICE '   - Entry deduction: check-in only (1 entry)';
    RAISE NOTICE '   - Check-out: no deduction';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Function signatures:';
    RAISE NOTICE '   1. process_pass_movement(pass_id, border_id, latitude, longitude, metadata)';
    RAISE NOTICE '   2. process_pass_movement(pass_id, border_id, latitude, longitude, notes)';
END $$;
