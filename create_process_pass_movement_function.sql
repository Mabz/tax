-- Create the process_pass_movement function for border control operations
-- Run this in your Supabase SQL editor

-- Create the process_pass_movement function
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
    SELECT * INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass not found'
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
        'border_official', -- Set authority type for border control
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;

    -- Update pass status and entries (without last_used_at since column may not exist)
    UPDATE purchased_passes 
    SET 
        current_status = v_new_status,
        entries_remaining = entries_remaining - v_entries_to_deduct
    WHERE id = p_pass_id;

    -- Get updated pass data
    SELECT * INTO v_pass_record FROM purchased_passes WHERE id = p_pass_id;

    -- Return success with updated data
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_remaining', v_pass_record.entries_remaining,
        'pass_data', to_jsonb(v_pass_record)
    );

    RETURN v_result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- Add comment
COMMENT ON FUNCTION process_pass_movement IS 'Processes pass movements at border control points (check-in/check-out)';

SELECT 'process_pass_movement function created successfully' as status;