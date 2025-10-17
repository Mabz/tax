-- Fix Entries Deduction Issue
-- This addresses the specific problem where entries aren't being deducted properly

-- First, let's check the specific pass that's having issues
DO $$
DECLARE
    problem_pass_id UUID := '2a9fe188-b6c9-4d83-90e0-48a71f24b3b5';
    pass_data RECORD;
BEGIN
    RAISE NOTICE '🔍 ========== INVESTIGATING PROBLEM PASS ==========';
    
    SELECT * INTO pass_data
    FROM purchased_passes 
    WHERE id = problem_pass_id;
    
    IF FOUND THEN
        RAISE NOTICE '📋 Problem Pass Details:';
        RAISE NOTICE '   - ID: %', pass_data.id;
        RAISE NOTICE '   - Current Status: "%"', pass_data.current_status;
        RAISE NOTICE '   - Entries Remaining: %', pass_data.entries_remaining;
        RAISE NOTICE '   - Entry Limit: %', pass_data.entry_limit;
        RAISE NOTICE '   - Overall Status: "%"', pass_data.status;
        
        -- Check if this pass has any movements
        FOR pass_data IN 
            SELECT 
                movement_type,
                previous_status,
                new_status,
                entries_deducted,
                processed_at
            FROM pass_movements 
            WHERE pass_id = problem_pass_id
            ORDER BY processed_at DESC
            LIMIT 3
        LOOP
            RAISE NOTICE '   - Movement: % | % -> % | Deducted: % | At: %', 
                pass_data.movement_type,
                pass_data.previous_status,
                pass_data.new_status,
                pass_data.entries_deducted,
                pass_data.processed_at;
        END LOOP;
    ELSE
        RAISE NOTICE '❌ Pass not found';
    END IF;
END $$;

-- Create a completely rewritten process_pass_movement function with better logic
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
    
    RAISE NOTICE '🚀 ========== PROCESSING PASS MOVEMENT ==========';
    RAISE NOTICE '📋 Pass ID: %', p_pass_id;
    RAISE NOTICE '🏢 Border ID: %', p_border_id;
    RAISE NOTICE '👤 User ID: %', v_current_user_id;
    
    IF v_current_user_id IS NULL THEN
        RAISE NOTICE '❌ User not authenticated';
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not authenticated'
        );
    END IF;

    -- Get pass details with explicit column selection
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
        RAISE NOTICE '❌ Pass not found';
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass not found'
        );
    END IF;

    -- Store original entries for comparison
    v_entries_before := v_pass_record.entries_remaining;
    
    RAISE NOTICE '📊 Pass Status: "%"', v_pass_record.current_status;
    RAISE NOTICE '📊 Entries Before: %', v_entries_before;
    RAISE NOTICE '📊 Entry Limit: %', v_pass_record.entry_limit;
    RAISE NOTICE '📊 Overall Status: "%"', v_pass_record.status;

    -- Determine movement type with explicit status checking
    -- For check-in: pass should be ready to enter (active, unused, or checked_out)
    IF v_pass_record.current_status IN ('active', 'unused', 'checked_out') THEN
        v_movement_type := 'check_in';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'checked_in';
        v_entries_to_deduct := 1;
        
        RAISE NOTICE '✅ Determined: CHECK-IN (%s -> %s, deduct %s)', 
            v_previous_status, v_new_status, v_entries_to_deduct;
        
    -- For check-out: pass should be currently in transit (checked_in, in_transit)
    ELSIF v_pass_record.current_status IN ('checked_in', 'in_transit') THEN
        v_movement_type := 'check_out';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'checked_out';
        v_entries_to_deduct := 0; -- No deduction for check-out
        
        RAISE NOTICE '✅ Determined: CHECK-OUT (%s -> %s, deduct %s)', 
            v_previous_status, v_new_status, v_entries_to_deduct;
        
    ELSE
        RAISE NOTICE '❌ Invalid status for processing: "%"', v_pass_record.current_status;
        RETURN jsonb_build_object(
            'success', false,
            'error', format('Pass status "%s" does not allow movement processing. Valid check-in statuses: active, unused, checked_out. Valid check-out statuses: checked_in, in_transit.', v_pass_record.current_status),
            'current_status', v_pass_record.current_status
        );
    END IF;

    -- Validate sufficient entries for check-in
    IF v_movement_type = 'check_in' AND v_entries_before < v_entries_to_deduct THEN
        RAISE NOTICE '❌ Insufficient entries: % available, % needed', v_entries_before, v_entries_to_deduct;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient entries remaining',
            'entries_remaining', v_entries_before,
            'entries_needed', v_entries_to_deduct
        );
    END IF;

    -- Enhance metadata
    p_metadata := p_metadata || jsonb_build_object(
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_before', v_entries_before,
        'processed_by', v_current_user_id,
        'processed_at', NOW(),
        'function_version', 'fixed_v2'
    );

    -- Insert movement record
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

    RAISE NOTICE '📝 Movement record created: %', v_movement_id;

    -- Update pass with explicit calculation
    UPDATE purchased_passes 
    SET 
        current_status = v_new_status,
        entries_remaining = entries_remaining - v_entries_to_deduct,
        updated_at = NOW()
    WHERE id = p_pass_id;

    -- Verify the update worked
    SELECT entries_remaining INTO v_entries_after
    FROM purchased_passes 
    WHERE id = p_pass_id;

    RAISE NOTICE '📊 Entries After Update: %', v_entries_after;
    RAISE NOTICE '🔢 Expected After: %', (v_entries_before - v_entries_to_deduct);
    
    IF v_entries_after != (v_entries_before - v_entries_to_deduct) THEN
        RAISE NOTICE '⚠️ WARNING: Entries calculation mismatch!';
    END IF;

    -- Get complete updated pass data
    SELECT * INTO v_pass_record FROM purchased_passes WHERE id = p_pass_id;

    -- Build result
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_to_deduct,
        'entries_remaining', v_pass_record.entries_remaining,
        'entries_before', v_entries_before,
        'entries_after', v_entries_after,
        'calculation_correct', (v_entries_after = v_entries_before - v_entries_to_deduct),
        'pass_data', to_jsonb(v_pass_record)
    );

    RAISE NOTICE '🎉 Processing completed successfully';
    RAISE NOTICE '📊 Final Result: entries_remaining = %', v_pass_record.entries_remaining;
    RAISE NOTICE '========== END PROCESSING ==========';
    
    RETURN v_result;
END;
$$;

-- Create a test function to verify the fix works
CREATE OR REPLACE FUNCTION test_pass_processing(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
    v_test_border_id UUID := '00000000-0000-0000-0000-000000000001'; -- Dummy border ID
BEGIN
    RAISE NOTICE '🧪 ========== TESTING PASS PROCESSING ==========';
    
    -- Call the function with test parameters
    SELECT process_pass_movement(
        p_pass_id,
        v_test_border_id,
        -26.3054, -- Test coordinates
        31.1367,
        'Test processing',
        '{"test": true}'::jsonb
    ) INTO v_result;
    
    RAISE NOTICE '🧪 Test Result: %', v_result;
    RAISE NOTICE '========== END TEST ==========';
    
    RETURN v_result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION test_pass_processing TO authenticated;

-- Success message
SELECT '✅ Fixed process_pass_movement function created' as status;
SELECT '🧪 You can test with: SELECT test_pass_processing(''2a9fe188-b6c9-4d83-90e0-48a71f24b3b5'');' as test_command;