-- Enable real-time updates for purchased_passes table
-- Run this script in Supabase SQL Editor

-- Ensure the purchased_passes table has proper replica identity for real-time updates
ALTER TABLE purchased_passes REPLICA IDENTITY FULL;

-- Create a function to manually trigger real-time notifications
CREATE OR REPLACE FUNCTION trigger_pass_realtime_update(p_pass_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update the pass to trigger real-time notification
    UPDATE purchased_passes 
    SET updated_at = NOW() 
    WHERE id = p_pass_id;
    
    -- Log the trigger
    RAISE NOTICE 'Triggered real-time update for pass: %', p_pass_id;
END;
$$;

-- Update the process_pass_movement function to ensure real-time updates
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
        
        -- Check if pass has remaining entries
        IF COALESCE(v_pass_record.entries_remaining, 0) < 1 THEN
            RAISE EXCEPTION 'No entries remaining on pass';
        END IF;
        
    ELSIF v_previous_status = 'checked_in' THEN
        v_movement_type := 'check_out';
        v_new_status := 'checked_out';
        v_entries_deducted := 0;
        
    ELSE
        RAISE EXCEPTION 'Invalid pass status for movement: %', v_previous_status;
    END IF;
    
    -- Calculate new entries remaining
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
    
    -- Update the pass status and entries (this will trigger real-time updates)
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Explicitly trigger real-time notification
    PERFORM trigger_pass_realtime_update(p_pass_id);
    
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
        'processed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_pass_realtime_update TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Real-time Updates Enhanced!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Set REPLICA IDENTITY FULL for purchased_passes';
    RAISE NOTICE 'Created trigger_pass_realtime_update function';
    RAISE NOTICE 'Enhanced process_pass_movement with explicit notifications';
    RAISE NOTICE 'Real-time updates should now work properly!';
    RAISE NOTICE '=================================================================';
END $$;