-- Fix pass_movements table by adding missing columns
-- Run this script in Supabase SQL Editor

-- Add missing columns to pass_movements table if they don't exist
DO $$
BEGIN
    -- Add official_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'official_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN official_id UUID;
        COMMENT ON COLUMN pass_movements.official_id IS 'ID of the border official who processed the movement';
        RAISE NOTICE 'Added official_id column to pass_movements';
    END IF;
    
    -- Add movement_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'movement_type'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN movement_type TEXT CHECK (movement_type IN ('check_in', 'check_out'));
        COMMENT ON COLUMN pass_movements.movement_type IS 'Type of movement: check_in or check_out';
        RAISE NOTICE 'Added movement_type column to pass_movements';
    END IF;
    
    -- Add previous_status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'previous_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN previous_status TEXT;
        COMMENT ON COLUMN pass_movements.previous_status IS 'Previous status of the pass before movement';
        RAISE NOTICE 'Added previous_status column to pass_movements';
    END IF;
    
    -- Add new_status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'new_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN new_status TEXT;
        COMMENT ON COLUMN pass_movements.new_status IS 'New status of the pass after movement';
        RAISE NOTICE 'Added new_status column to pass_movements';
    END IF;
    
    -- Add entries_deducted column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'entries_deducted'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN entries_deducted INTEGER DEFAULT 0;
        COMMENT ON COLUMN pass_movements.entries_deducted IS 'Number of entries deducted in this movement';
        RAISE NOTICE 'Added entries_deducted column to pass_movements';
    END IF;
    
    -- Add latitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'latitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN latitude DECIMAL(10, 8);
        COMMENT ON COLUMN pass_movements.latitude IS 'GPS latitude of the movement location';
        RAISE NOTICE 'Added latitude column to pass_movements';
    END IF;
    
    -- Add longitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'longitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN longitude DECIMAL(11, 8);
        COMMENT ON COLUMN pass_movements.longitude IS 'GPS longitude of the movement location';
        RAISE NOTICE 'Added longitude column to pass_movements';
    END IF;
    
    -- Add metadata column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'metadata'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN metadata JSONB DEFAULT '{}';
        COMMENT ON COLUMN pass_movements.metadata IS 'Additional metadata for the movement';
        RAISE NOTICE 'Added metadata column to pass_movements';
    END IF;
    
    -- Add processed_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'processed_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        COMMENT ON COLUMN pass_movements.processed_at IS 'When the movement was processed';
        RAISE NOTICE 'Added processed_at column to pass_movements';
    END IF;
    
    -- Add updated_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'updated_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE pass_movements ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        COMMENT ON COLUMN pass_movements.updated_at IS 'When the record was last updated';
        RAISE NOTICE 'Added updated_at column to pass_movements';
    END IF;
END $$;

-- Add missing columns to purchased_passes table if they don't exist
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
        COMMENT ON COLUMN purchased_passes.current_status IS 'Current status: unused, checked_in, checked_out, expired';
        RAISE NOTICE 'Added current_status column to purchased_passes';
    END IF;
    
    -- Add entries_remaining column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'entries_remaining'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entries_remaining INTEGER;
        COMMENT ON COLUMN purchased_passes.entries_remaining IS 'Number of entries remaining on the pass';
        RAISE NOTICE 'Added entries_remaining column to purchased_passes';
        
        -- Initialize entries_remaining for existing passes
        UPDATE purchased_passes pp
        SET entries_remaining = COALESCE(pt.entry_limit, 1)
        FROM pass_templates pt
        WHERE pp.pass_template_id = pt.id
        AND pp.entries_remaining IS NULL;
        
        -- For passes without template reference, set default
        UPDATE purchased_passes 
        SET entries_remaining = 1 
        WHERE entries_remaining IS NULL;
        
        RAISE NOTICE 'Initialized entries_remaining for existing passes';
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pass_movements_official_id ON pass_movements(official_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_movement_type ON pass_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_pass_movements_processed_at ON pass_movements(processed_at);

-- Create the process_pass_movement function
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
        -- Log the error and re-raise with more context
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- Enable RLS on pass_movements if not already enabled
ALTER TABLE pass_movements ENABLE ROW LEVEL SECURITY;

-- Create basic RLS policy for pass_movements
DROP POLICY IF EXISTS "Users can view their own pass movements" ON pass_movements;
CREATE POLICY "Users can view their own pass movements" ON pass_movements
    FOR SELECT USING (
        pass_id IN (
            SELECT id FROM purchased_passes WHERE profile_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Border officials can insert movements" ON pass_movements;
CREATE POLICY "Border officials can insert movements" ON pass_movements
    FOR INSERT WITH CHECK (official_id = auth.uid());

-- Success message
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Pass Movements Table Fixed!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Added missing columns to pass_movements table';
    RAISE NOTICE 'Created process_pass_movement function';
    RAISE NOTICE 'Set up basic RLS policies';
    RAISE NOTICE 'Border Control should now work properly!';
    RAISE NOTICE '=================================================================';
END $$;