-- Direct fix for pass_movements table column issue
-- Run this script in Supabase SQL Editor

-- First, let's make the border_official_profile_id column nullable
DO $$
BEGIN
    -- Remove NOT NULL constraint from border_official_profile_id
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'border_official_profile_id'
        AND table_schema = 'public'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE pass_movements ALTER COLUMN border_official_profile_id DROP NOT NULL;
        RAISE NOTICE 'Removed NOT NULL constraint from border_official_profile_id';
    END IF;
    
    -- Add official_id column if it doesn't exist (as an alias)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'official_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN official_id UUID;
        RAISE NOTICE 'Added official_id column';
    END IF;
END $$;

-- Update the process_pass_movement function to work with the existing column structure
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
    v_insert_sql TEXT;
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
    
    -- Create the movement record using dynamic SQL to handle different column names
    BEGIN
        -- Try inserting with border_official_profile_id first
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
        
    EXCEPTION
        WHEN undefined_column THEN
            -- If border_official_profile_id doesn't exist, try with official_id
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
    END;
    
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

-- Alternative: Create a simpler function that works with minimal columns
CREATE OR REPLACE FUNCTION process_pass_movement_simple(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL
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
    
    -- Insert with only the columns that definitely exist
    INSERT INTO pass_movements (
        pass_id,
        border_id,
        border_official_profile_id
    ) VALUES (
        p_pass_id,
        p_border_id,
        v_official_id
    ) RETURNING id INTO v_movement_id;
    
    -- Update the pass status and entries
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Return the result
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
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION process_pass_movement_simple TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Direct Fix Applied!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Removed NOT NULL constraint from border_official_profile_id';
    RAISE NOTICE 'Created flexible process_pass_movement function';
    RAISE NOTICE 'Created simple fallback function';
    RAISE NOTICE 'Border Control should now work!';
    RAISE NOTICE '=================================================================';
END $$;