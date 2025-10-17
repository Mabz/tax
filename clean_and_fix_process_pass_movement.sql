-- Clean and Fix process_pass_movement Function
-- This removes all existing versions and creates the correct one

-- First, let's see what versions exist
SELECT 
    p.proname as function_name,
    p.pronargs as num_args,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
WHERE p.proname = 'process_pass_movement'
ORDER BY p.oid;

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, TEXT, JSONB);
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, JSONB);
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, TEXT);
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL);
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID);
DROP FUNCTION IF EXISTS process_pass_movement_with_gps_validation;

-- Also drop any test functions
DROP FUNCTION IF EXISTS test_pass_processing(UUID);

-- Now create the single, correct version
CREATE OR REPLACE FUNCTION process_pass_movement(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
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
    v_entries_before INTEGER;
    v_entries_after INTEGER;
BEGIN
    -- Get current user (border official)
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not authenticated'
        );
    END IF;

    -- Get pass details
    SELECT 
        id,
        current_status,
        entries_remaining,
        entry_limit,
        status,
        expires_at
    INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass not found'
        );
    END IF;

    -- Store original entries for debugging
    v_entries_before := v_pass_record.entries_remaining;

    -- Determine movement type based on current status
    -- Handle various status values that might exist
    IF v_pass_record.current_status IN ('active', 'unused', 'checked_out') THEN
        v_movement_type := 'check_in';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'checked_in';
        v_entries_to_deduct := 1;
        
    ELSIF v_pass_record.current_status IN ('checked_in', 'in_transit') THEN
        v_movement_type := 'check_out';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'checked_out';
        v_entries_to_deduct := 0; -- No deduction for check-out
        
    ELSE
        -- Return detailed error for debugging
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Pass status "%s" does not allow movement processing', v_pass_record.current_status),
            'current_status', v_pass_record.current_status,
            'entries_remaining', v_pass_record.entries_remaining,
            'entry_limit', v_pass_record.entry_limit,
            'overall_status', v_pass_record.status,
            'valid_checkin_statuses', ARRAY['active', 'unused', 'checked_out'],
            'valid_checkout_statuses', ARRAY['checked_in', 'in_transit']
        );
    END IF;

    -- Check if pass has enough entries for check-in
    IF v_movement_type = 'check_in' AND v_entries_before < v_entries_to_deduct THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient entries remaining',
            'entries_remaining', v_entries_before,
            'entries_needed', v_entries_to_deduct
        );
    END IF;

    -- Enhance metadata with movement information
    p_metadata := p_metadata || jsonb_build_object(
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_before', v_entries_before,
        'processed_by', v_current_user_id,
        'processed_at', NOW(),
        'function_version', 'clean_v2'
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
        notes,
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
        p_notes,
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

    -- Get the updated entries count for verification
    SELECT entries_remaining INTO v_entries_after
    FROM purchased_passes 
    WHERE id = p_pass_id;

    -- Get complete updated pass data
    SELECT * INTO v_pass_record FROM purchased_passes WHERE id = p_pass_id;

    -- Return success with detailed information
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_remaining', v_pass_record.entries_remaining,
        'debug_info', jsonb_build_object(
            'entries_before', v_entries_before,
            'entries_after', v_entries_after,
            'calculation_correct', (v_entries_after = v_entries_before - v_entries_to_deduct),
            'function_version', 'clean_v2',
            'timestamp', NOW()
        ),
        'pass_data', to_jsonb(v_pass_record)
    );

    RETURN v_result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- Add comment
COMMENT ON FUNCTION process_pass_movement IS 'Processes pass movements at border control points with improved status logic and debugging';

-- Verify the function was created correctly
SELECT 
    p.proname as function_name,
    p.pronargs as num_args,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
WHERE p.proname = 'process_pass_movement';

-- Success message
SELECT '✅ Clean process_pass_movement function created successfully' as status;
SELECT 'Function signature: process_pass_movement(p_pass_id UUID, p_border_id UUID, p_latitude DECIMAL, p_longitude DECIMAL, p_notes TEXT, p_metadata JSONB)' as signature;