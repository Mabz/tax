-- Add scan_purpose column to pass_movements table
-- Run this in your Supabase SQL editor

-- Add the scan_purpose column if it doesn't exist
DO $$
BEGIN
    -- Check if scan_purpose column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'scan_purpose'
    ) THEN
        -- Add the column
        ALTER TABLE pass_movements ADD COLUMN scan_purpose TEXT;
        RAISE NOTICE '✅ Added scan_purpose column to pass_movements table';
    ELSE
        RAISE NOTICE '⚠️ scan_purpose column already exists';
    END IF;
END;
$$;

-- Update the update_movement_record function to use the new column
CREATE OR REPLACE FUNCTION update_movement_record(
    p_movement_id UUID,
    p_scan_purpose TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_count INTEGER;
    v_result JSONB;
BEGIN
    -- Update the movement record with scan_purpose in its own column
    UPDATE pass_movements 
    SET 
        notes = COALESCE(p_notes, notes), -- Keep existing notes if new ones are null
        scan_purpose = p_scan_purpose, -- Update the scan_purpose column
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'updated_at', NOW(),
            'status', 'completed',
            'authority_type', 'local_authority'
        )
    WHERE id = p_movement_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Movement record not found: %', p_movement_id;
    END IF;
    
    -- Return success info
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', p_movement_id,
        'scan_purpose', p_scan_purpose,
        'notes', p_notes,
        'updated_at', NOW()
    );
    
    RETURN v_result;
END;
$$;

-- Also update the log_local_authority_scan function to use the scan_purpose column
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
        'scan_timestamp', NOW(),
        'user_id', v_current_user_id,
        'status', 'in_progress'
    );
    
    -- Insert new scan record with scan_purpose in its own column
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
        scan_purpose,  -- Use the new column
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
        p_scan_purpose, -- Set the scan purpose
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;
    
    RETURN v_movement_id;
END;
$$;

SELECT 'scan_purpose column and functions updated successfully' as status;