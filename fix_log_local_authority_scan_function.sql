-- Fix the log_local_authority_scan function to remove the non-existent column reference
-- Run this in your Supabase SQL editor

-- Enhanced log_local_authority_scan function that prevents duplicates
CREATE OR REPLACE FUNCTION log_local_authority_scan(
    p_pass_id UUID,
    p_authority_type TEXT DEFAULT 'local_authority',
    p_scan_purpose TEXT DEFAULT 'scan_initiated',
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_movement_id UUID;
    v_current_user_id UUID;
    v_existing_movement_id UUID;
BEGIN
    -- Get current user (could be null for anonymous scans)
    v_current_user_id := auth.uid();
    
    -- Verify pass exists
    IF NOT EXISTS (SELECT 1 FROM purchased_passes WHERE id = p_pass_id) THEN
        RAISE EXCEPTION 'Pass not found: %', p_pass_id;
    END IF;
    
    -- Check if there's already a recent scan for this pass by this user (within last 5 minutes)
    -- This prevents duplicate entries during the same scan session
    SELECT id INTO v_existing_movement_id
    FROM pass_movements 
    WHERE pass_id = p_pass_id 
      AND profile_id = v_current_user_id
      AND movement_type = 'local_authority_scan'
      AND processed_at > NOW() - INTERVAL '5 minutes'
      AND (metadata->>'status' IS NULL OR metadata->>'status' != 'completed')
    ORDER BY processed_at DESC
    LIMIT 1;
    
    -- If we found a recent incomplete scan, return its ID instead of creating a new one
    IF v_existing_movement_id IS NOT NULL THEN
        RAISE NOTICE 'Found existing incomplete scan: %', v_existing_movement_id;
        RETURN v_existing_movement_id;
    END IF;
    
    -- Enhance metadata with scan information
    p_metadata := p_metadata || jsonb_build_object(
        'authority_type', p_authority_type,
        'scan_purpose', p_scan_purpose,
        'scan_timestamp', NOW(),
        'user_id', v_current_user_id,
        'status', 'in_progress'
    );
    
    -- Insert new scan record
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
        metadata,
        processed_at
    ) VALUES (
        p_pass_id,
        NULL, -- No border for local authority scans
        v_current_user_id,
        'local_authority_scan', -- Always local authority scan
        NULL, -- No previous status tracking needed
        NULL, -- No new status tracking needed
        0, -- Never deduct entries for local authority scans
        p_latitude,
        p_longitude,
        p_notes,
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;
    
    RETURN v_movement_id;
END;
$$;

-- Add comment
COMMENT ON FUNCTION log_local_authority_scan IS 'Logs local authority scans in pass_movements table (fixed to remove last_used_at reference)';

SELECT 'log_local_authority_scan function updated - removed last_used_at column reference' as status;