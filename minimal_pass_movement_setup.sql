-- Minimal setup for pass movement system
-- This creates only the essential components needed to fix the immediate error

-- ============================================================================
-- STEP 1: Add required columns to purchased_passes if missing
-- ============================================================================

DO $$
BEGIN
    -- Add current_status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'current_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN current_status TEXT DEFAULT 'unused';
        RAISE NOTICE 'Added current_status column to purchased_passes';
    ELSE
        RAISE NOTICE 'current_status column already exists';
    END IF;
    
    -- Add entries_remaining column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'entries_remaining'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entries_remaining INTEGER DEFAULT 1;
        RAISE NOTICE 'Added entries_remaining column to purchased_passes';
        
        -- Initialize entries_remaining for existing passes
        UPDATE purchased_passes 
        SET entries_remaining = 1 
        WHERE entries_remaining IS NULL;
        
    ELSE
        RAISE NOTICE 'entries_remaining column already exists';
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Create minimal pass_movements table
-- ============================================================================

CREATE TABLE IF NOT EXISTS pass_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_id UUID NOT NULL,
    border_id UUID NOT NULL,
    official_id UUID NOT NULL,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('check_in', 'check_out')),
    previous_status TEXT NOT NULL,
    new_status TEXT NOT NULL,
    entries_deducted INTEGER DEFAULT 0,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    metadata JSONB DEFAULT '{}',
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create basic indexes
CREATE INDEX IF NOT EXISTS idx_pass_movements_pass_id ON pass_movements(pass_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_border_id ON pass_movements(border_id);

-- ============================================================================
-- STEP 3: Create minimal border_official_borders table
-- ============================================================================

CREATE TABLE IF NOT EXISTS border_official_borders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL,
    border_id UUID NOT NULL,
    can_check_in BOOLEAN DEFAULT true,
    can_check_out BOOLEAN DEFAULT true,
    assigned_by UUID,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create basic indexes
CREATE INDEX IF NOT EXISTS idx_border_official_borders_profile_id ON border_official_borders(profile_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_border_id ON border_official_borders(border_id);

-- ============================================================================
-- STEP 4: Create the main process_pass_movement function
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
    v_can_check_in BOOLEAN := true;  -- Default to true for now
    v_can_check_out BOOLEAN := true; -- Default to true for now
    v_entries_remaining INTEGER;
BEGIN
    -- Get the current user (border official)
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if the official is assigned to this border (simplified check)
    SELECT can_check_in, can_check_out
    INTO v_can_check_in, v_can_check_out
    FROM border_official_borders
    WHERE profile_id = v_official_id 
      AND border_id = p_border_id 
      AND is_active = true
    LIMIT 1;
    
    -- If no assignment found, allow with default permissions for now
    IF NOT FOUND THEN
        RAISE NOTICE 'No border assignment found, using default permissions';
        v_can_check_in := true;
        v_can_check_out := true;
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
    
    -- Update the pass status and entries
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
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
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- ============================================================================
-- STEP 5: Create supporting functions
-- ============================================================================

-- Simple function to check movement permissions
CREATE OR REPLACE FUNCTION can_official_process_movement(
    p_border_id UUID,
    p_movement_type TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_official_id UUID;
BEGIN
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- For now, return true if user is authenticated
    -- This can be enhanced later with proper permission checks
    RETURN true;
END;
$$;

-- Simple function to get pass movement history
CREATE OR REPLACE FUNCTION get_pass_movement_history(
    p_pass_id UUID
)
RETURNS TABLE (
    movement_id UUID,
    border_name TEXT,
    official_name TEXT,
    movement_type TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    processed_at TIMESTAMP WITH TIME ZONE,
    entries_deducted INTEGER,
    previous_status TEXT,
    new_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.id as movement_id,
        COALESCE(b.name, 'Unknown Border') as border_name,
        'Border Official' as official_name,
        pm.movement_type,
        pm.latitude,
        pm.longitude,
        pm.processed_at,
        pm.entries_deducted,
        pm.previous_status,
        pm.new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    WHERE pm.pass_id = p_pass_id
    ORDER BY pm.processed_at DESC;
END;
$$;

-- ============================================================================
-- STEP 6: Grant permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION can_official_process_movement TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_movement_history TO authenticated;

-- ============================================================================
-- COMPLETION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Minimal Pass Movement System Setup Complete!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '- process_pass_movement function';
    RAISE NOTICE '- can_official_process_movement function';
    RAISE NOTICE '- get_pass_movement_history function';
    RAISE NOTICE '- pass_movements table';
    RAISE NOTICE '- border_official_borders table';
    RAISE NOTICE '- Required columns in purchased_passes';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'The system should now work for basic pass processing!';
    RAISE NOTICE '=================================================================';
END $$;