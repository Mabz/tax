-- Check and fix the actual table structure
-- Run this script in Supabase SQL Editor

-- First, let's see what the actual pass_movements table looks like
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'CHECKING PASS_MOVEMENTS TABLE STRUCTURE';
    RAISE NOTICE '=================================================================';
END $$;

-- Check what columns exist in pass_movements table
SELECT 
    'PASS_MOVEMENTS COLUMNS' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_movements' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check constraints on pass_movements table
SELECT 
    'PASS_MOVEMENTS CONSTRAINTS' as section,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'pass_movements' 
AND table_schema = 'public';

-- Now let's fix the issues based on what we found
DO $$
BEGIN
    -- If border_official_profile_id exists but official_id doesn't, rename it
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'border_official_profile_id'
        AND table_schema = 'public'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'official_id'
        AND table_schema = 'public'
    ) THEN
        -- Rename the column to match what our function expects
        ALTER TABLE pass_movements RENAME COLUMN border_official_profile_id TO official_id;
        RAISE NOTICE 'Renamed border_official_profile_id to official_id';
    END IF;
    
    -- If official_id has NOT NULL constraint, make it nullable
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'official_id'
        AND table_schema = 'public'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE pass_movements ALTER COLUMN official_id DROP NOT NULL;
        RAISE NOTICE 'Removed NOT NULL constraint from official_id';
    END IF;
    
    -- Add missing columns if they don't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'movement_type'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN movement_type TEXT;
        RAISE NOTICE 'Added movement_type column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'previous_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN previous_status TEXT;
        RAISE NOTICE 'Added previous_status column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'new_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN new_status TEXT;
        RAISE NOTICE 'Added new_status column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'entries_deducted'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN entries_deducted INTEGER DEFAULT 0;
        RAISE NOTICE 'Added entries_deducted column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'latitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN latitude DECIMAL(10, 8);
        RAISE NOTICE 'Added latitude column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'longitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN longitude DECIMAL(11, 8);
        RAISE NOTICE 'Added longitude column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'metadata'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN metadata JSONB DEFAULT '{}';
        RAISE NOTICE 'Added metadata column';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'processed_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'Added processed_at column';
    END IF;
END $$;

-- Update the process_pass_movement function to handle the current user properly
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
    v_entries_remaining INTEGER;
BEGIN
    -- Get the current user (border official)
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    RAISE NOTICE 'Processing movement for pass % by official %', p_pass_id, v_official_id;
    
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
    
    RAISE NOTICE 'Creating movement record: type=%, official=%, border=%', v_movement_type, v_official_id, p_border_id;
    
    -- Create the movement record
    INSERT INTO pass_movements (
        pass_id,
        border_id,
        official_id,
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
    
    RAISE NOTICE 'Movement record created with ID: %', v_movement_id;
    
    -- Update the pass status and entries
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    RAISE NOTICE 'Pass updated: status=%, entries_remaining=%', v_new_status, v_entries_remaining;
    
    -- Return the result in the expected format
    RETURN jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_deducted,
        'entries_remaining', v_entries_remaining,
        'processed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise with more context
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Table Structure Fixed!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Fixed column names and constraints';
    RAISE NOTICE 'Updated process_pass_movement function';
    RAISE NOTICE 'Added debug logging';
    RAISE NOTICE 'Border Control should now work!';
    RAISE NOTICE '=================================================================';
END $$;