-- Fix the checkout logic for passes with no entries remaining
-- A vehicle that is "checked_in" should always be able to check out, regardless of entries remaining

-- ============================================================================
-- STEP 1: Update the process_pass_movement function to allow checkout when checked_in
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
    v_official_id UUID;
    v_pass_record RECORD;
    v_movement_type TEXT;
    v_previous_status TEXT;
    v_new_status TEXT;
    v_entries_deducted INTEGER := 0;
    v_movement_id UUID;
    v_audit_id UUID;
    v_entries_remaining INTEGER;
    v_border_name TEXT;
    v_official_name TEXT;
    v_secure_code TEXT;
BEGIN
    -- Get the current user (border official)
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Get the current pass information
    SELECT *
    INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass not found';
    END IF;
    
    -- Check if pass is expired
    IF v_pass_record.expires_at < NOW() THEN
        RAISE EXCEPTION 'Pass has expired';
    END IF;
    
    -- Get border name for logging
    SELECT name INTO v_border_name FROM borders WHERE id = p_border_id;
    
    -- Get official name for logging
    SELECT full_name INTO v_official_name FROM profiles WHERE id = v_official_id;
    
    -- Determine movement type based on current status
    v_previous_status := COALESCE(v_pass_record.current_status, 'unused');
    
    IF v_previous_status IN ('unused', 'checked_out') THEN
        v_movement_type := 'check_in';
        v_new_status := 'checked_in';
        v_entries_deducted := 1;
        
        -- Check if pass has remaining entries FOR CHECK-IN ONLY
        IF COALESCE(v_pass_record.entries_remaining, 0) < 1 THEN
            RAISE EXCEPTION 'No entries remaining on pass';
        END IF;
        
    ELSIF v_previous_status = 'checked_in' THEN
        -- IMPORTANT FIX: Allow check-out even if entries_remaining = 0
        -- A vehicle that is in the country MUST be allowed to leave
        v_movement_type := 'check_out';
        v_new_status := 'checked_out';
        v_entries_deducted := 0; -- Check-out doesn't consume entries
        
        -- NO CHECK for entries_remaining here - vehicle must be allowed to exit!
        
    ELSE
        RAISE EXCEPTION 'Invalid pass status for movement: %', v_previous_status;
    END IF;
    
    -- Calculate new entries remaining (only deduct for check-in)
    v_entries_remaining := COALESCE(v_pass_record.entries_remaining, 0) - v_entries_deducted;
    
    -- Create the movement record
    INSERT INTO pass_movements (
        pass_id,
        border_id,
        border_official_profile_id,
        movement_type,
        previous_status,
        new_status,
        entries_deducted,
        latitude,
        longitude,
        metadata,
        processed_at
    ) VALUES (
        p_pass_id,
        p_border_id,
        v_official_id,
        v_movement_type,
        v_previous_status,
        v_new_status,
        v_entries_deducted,
        p_latitude,
        p_longitude,
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;
    
    -- Create audit log entry
    INSERT INTO pass_processing_audit (
        pass_id,
        action_type,
        performed_by,
        performed_at,
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
        v_movement_type,
        v_official_id,
        NOW(),
        v_previous_status,
        v_new_status,
        v_entries_deducted,
        v_entries_remaining,
        p_border_id,
        COALESCE(v_border_name, 'Unknown Border'),
        COALESCE(v_official_name, 'Unknown Official'),
        p_latitude,
        p_longitude,
        p_metadata
    ) RETURNING id INTO v_audit_id;
    
    -- Generate secure code
    v_secure_code := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    
    -- Update the pass status, entries, and secure code
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        secure_code = v_secure_code,
        secure_code_expires_at = NOW() + INTERVAL '15 minutes',
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Return the result
    RETURN jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'audit_id', v_audit_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_deducted,
        'entries_remaining', v_entries_remaining,
        'secure_code', v_secure_code,
        'secure_code_expires_at', NOW() + INTERVAL '15 minutes',
        'processed_at', NOW(),
        'message', CASE 
            WHEN v_movement_type = 'check_out' AND v_pass_record.entries_remaining = 0 THEN
                'Vehicle checked out successfully (pass now fully consumed)'
            ELSE
                'Movement processed successfully'
        END
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- ============================================================================
-- STEP 2: Create a function to fix the status display logic
-- ============================================================================

-- This function returns the correct status for a pass considering vehicle location
CREATE OR REPLACE FUNCTION get_pass_display_status(
    p_entries_remaining INTEGER,
    p_current_status TEXT,
    p_pass_status TEXT,
    p_expires_at TIMESTAMP WITH TIME ZONE,
    p_activation_date TIMESTAMP WITH TIME ZONE
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Check if expired by date
    IF p_expires_at <= NOW() THEN
        RETURN 'Expired';
    END IF;
    
    -- Check if not yet activated
    IF p_activation_date > NOW() THEN
        RETURN 'Pending Activation';
    END IF;
    
    -- Check if pass is not active
    IF p_pass_status != 'active' THEN
        RETURN UPPER(p_pass_status);
    END IF;
    
    -- IMPORTANT: Check vehicle status first, then entries
    -- If vehicle is in country, pass is still "Active" even with 0 entries
    IF p_current_status = 'checked_in' THEN
        RETURN 'Active'; -- Vehicle in country, can still check out
    END IF;
    
    -- If vehicle has checked out and no entries remaining, then it's consumed
    IF p_current_status = 'checked_out' AND p_entries_remaining <= 0 THEN
        RETURN 'Consumed';
    END IF;
    
    -- If vehicle hasn't entered and no entries remaining, it's consumed
    IF (p_current_status IS NULL OR p_current_status = 'unused') AND p_entries_remaining <= 0 THEN
        RETURN 'Consumed';
    END IF;
    
    -- Otherwise, it's active
    RETURN 'Active';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_pass_display_status TO authenticated;

-- ============================================================================
-- STEP 3: Test the fix
-- ============================================================================

-- Function to test checkout with zero entries
CREATE OR REPLACE FUNCTION test_checkout_with_zero_entries()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_test_pass_id UUID;
    v_border_id UUID;
    v_result JSONB;
    v_pass_status RECORD;
BEGIN
    -- Find a pass that is checked_in with 0 entries remaining
    SELECT id INTO v_test_pass_id
    FROM purchased_passes
    WHERE current_status = 'checked_in'
    AND entries_remaining = 0
    AND status = 'active'
    AND expires_at > NOW()
    LIMIT 1;
    
    IF v_test_pass_id IS NULL THEN
        -- Create a test scenario: find any checked_in pass and set entries to 0
        SELECT id INTO v_test_pass_id
        FROM purchased_passes
        WHERE current_status = 'checked_in'
        AND status = 'active'
        AND expires_at > NOW()
        LIMIT 1;
        
        IF v_test_pass_id IS NOT NULL THEN
            -- Set entries to 0 to simulate the problem scenario
            UPDATE purchased_passes
            SET entries_remaining = 0
            WHERE id = v_test_pass_id;
        ELSE
            RETURN 'No checked_in passes found for testing';
        END IF;
    END IF;
    
    -- Get a border for testing
    SELECT id INTO v_border_id FROM borders LIMIT 1;
    
    IF v_border_id IS NULL THEN
        RETURN 'No borders found for testing';
    END IF;
    
    -- Get current pass status
    SELECT 
        current_status,
        entries_remaining,
        get_pass_display_status(entries_remaining, current_status, status, expires_at, activation_date) as display_status
    INTO v_pass_status
    FROM purchased_passes
    WHERE id = v_test_pass_id;
    
    -- Try to check out the vehicle
    SELECT process_pass_movement(
        v_test_pass_id,
        v_border_id,
        NULL,
        NULL,
        jsonb_build_object('test', 'checkout_with_zero_entries')
    ) INTO v_result;
    
    IF v_result->>'success' = 'true' THEN
        RETURN FORMAT('SUCCESS: Vehicle checked out! Status was: %s (entries: %s, display: %s) -> Now: %s', 
            v_pass_status.current_status, 
            v_pass_status.entries_remaining,
            v_pass_status.display_status,
            v_result->>'new_status'
        );
    ELSE
        RETURN 'FAILED: Could not check out vehicle';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION test_checkout_with_zero_entries TO authenticated;