-- Fix Border Processing Status Logic
-- This addresses the issue where entries aren't being deducted properly

-- First, let's check what status values we're actually dealing with
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '🔍 Current status values in purchased_passes:';
    FOR rec IN 
        SELECT current_status, COUNT(*) as count
        FROM purchased_passes 
        GROUP BY current_status
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   - Status: "%" (Count: %)', rec.current_status, rec.count;
    END LOOP;
END $$;

-- Create an improved version of the process_pass_movement function
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

    -- Log current pass state for debugging
    RAISE NOTICE '🔍 Processing pass: % with current_status: "%"', p_pass_id, v_pass_record.current_status;
    RAISE NOTICE '📊 Current entries_remaining: %', v_pass_record.entries_remaining;

    -- Improved status logic - handle more status variations
    -- Check if this is a check-in scenario
    IF v_pass_record.current_status IN ('active', 'unused', 'checked_out') THEN
        v_movement_type := 'check_in';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'checked_in'; -- Use more explicit status
        v_entries_to_deduct := 1;
        
        RAISE NOTICE '✅ Determined as CHECK-IN: % -> %', v_previous_status, v_new_status;
        
    -- Check if this is a check-out scenario  
    ELSIF v_pass_record.current_status IN ('in_transit', 'checked_in') THEN
        v_movement_type := 'check_out';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'checked_out'; -- Use more explicit status
        v_entries_to_deduct := 0; -- No additional deduction for check-out
        
        RAISE NOTICE '✅ Determined as CHECK-OUT: % -> %', v_previous_status, v_new_status;
        
    ELSE
        RAISE NOTICE '❌ Invalid status for processing: "%"', v_pass_record.current_status;
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Pass status "%s" does not allow movement processing', v_pass_record.current_status),
            'current_status', v_pass_record.current_status,
            'valid_checkin_statuses', ARRAY['active', 'unused', 'checked_out'],
            'valid_checkout_statuses', ARRAY['in_transit', 'checked_in']
        );
    END IF;

    -- Check if pass has enough entries for check-in
    IF v_movement_type = 'check_in' AND v_pass_record.entries_remaining < v_entries_to_deduct THEN
        RAISE NOTICE '❌ Insufficient entries: % remaining, % needed', v_pass_record.entries_remaining, v_entries_to_deduct;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient entries remaining',
            'entries_remaining', v_pass_record.entries_remaining,
            'entries_needed', v_entries_to_deduct
        );
    END IF;

    -- Enhance metadata with movement information
    p_metadata := p_metadata || jsonb_build_object(
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'processed_by', v_current_user_id,
        'processed_at', NOW(),
        'debug_info', jsonb_build_object(
            'original_status', v_pass_record.current_status,
            'original_entries', v_pass_record.entries_remaining
        )
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

    RAISE NOTICE '📝 Created movement record: %', v_movement_id;

    -- Update pass status and entries
    UPDATE purchased_passes 
    SET 
        current_status = v_new_status,
        entries_remaining = entries_remaining - v_entries_to_deduct,
        updated_at = NOW()
    WHERE id = p_pass_id;

    RAISE NOTICE '✅ Updated pass: status=%, entries deducted=%', v_new_status, v_entries_to_deduct;

    -- Get updated pass data to verify the update worked
    SELECT * INTO v_pass_record FROM purchased_passes WHERE id = p_pass_id;
    
    RAISE NOTICE '📊 Final entries_remaining: %', v_pass_record.entries_remaining;

    -- Return success with updated data
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_remaining', v_pass_record.entries_remaining,
        'debug_info', jsonb_build_object(
            'function_version', 'fixed_v1',
            'processing_timestamp', NOW()
        ),
        'pass_data', to_jsonb(v_pass_record)
    );

    RAISE NOTICE '🎉 Processing completed successfully';
    RETURN v_result;
END;
$$;

-- Also create a function to check and fix any passes with inconsistent status
CREATE OR REPLACE FUNCTION fix_pass_status_inconsistencies()
RETURNS TABLE (
    pass_id UUID,
    old_status TEXT,
    new_status TEXT,
    action_taken TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH status_fixes AS (
        UPDATE purchased_passes 
        SET current_status = CASE 
            -- If status is null or empty, set to 'active'
            WHEN current_status IS NULL OR current_status = '' THEN 'active'
            -- Normalize common variations
            WHEN current_status = 'in_transit' THEN 'checked_in'
            WHEN current_status = 'unused' THEN 'active'
            ELSE current_status
        END,
        updated_at = NOW()
        WHERE current_status IS NULL 
           OR current_status = '' 
           OR current_status = 'in_transit'
           OR current_status = 'unused'
        RETURNING 
            id as pass_id,
            current_status as new_status
    )
    SELECT 
        sf.pass_id,
        'inconsistent' as old_status,
        sf.new_status,
        'normalized_status' as action_taken
    FROM status_fixes sf;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION fix_pass_status_inconsistencies TO authenticated;

-- Run the status fix
SELECT * FROM fix_pass_status_inconsistencies();

RAISE NOTICE '✅ Border processing function updated with improved status logic and debugging';
RAISE NOTICE '📋 Run the debug script to check the specific pass that was having issues';