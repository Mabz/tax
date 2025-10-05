-- Create the missing process_pass_movement function for Supabase
-- This function handles pass check-in and check-out movements at borders

-- First, create the pass_movements table if it doesn't exist
CREATE TABLE IF NOT EXISTS pass_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_id UUID NOT NULL REFERENCES purchased_passes(id) ON DELETE CASCADE,
    border_id UUID NOT NULL REFERENCES borders(id) ON DELETE CASCADE,
    official_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pass_movements_pass_id ON pass_movements(pass_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_border_id ON pass_movements(border_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_processed_at ON pass_movements(processed_at);

-- Enable RLS on pass_movements table
ALTER TABLE pass_movements ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for pass_movements
CREATE POLICY "Users can view their own pass movements" ON pass_movements
    FOR SELECT USING (
        pass_id IN (
            SELECT id FROM purchased_passes WHERE profile_id = auth.uid()
        )
    );

CREATE POLICY "Border officials can view movements at their borders" ON pass_movements
    FOR SELECT USING (
        border_id IN (
            SELECT border_id FROM border_official_borders 
            WHERE profile_id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Border officials can insert movements at their borders" ON pass_movements
    FOR INSERT WITH CHECK (
        border_id IN (
            SELECT border_id FROM border_official_borders 
            WHERE profile_id = auth.uid() AND is_active = true
        )
    );

-- Create the main process_pass_movement function
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
    v_can_check_in BOOLEAN := false;
    v_can_check_out BOOLEAN := false;
BEGIN
    -- Get the current user (border official)
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if the official is assigned to this border and get permissions
    SELECT can_check_in, can_check_out
    INTO v_can_check_in, v_can_check_out
    FROM border_official_borders
    WHERE profile_id = v_official_id 
      AND border_id = p_border_id 
      AND is_active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Official not assigned to this border';
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
        
        -- Check if official can perform check-in
        IF NOT v_can_check_in THEN
            RAISE EXCEPTION 'Official does not have check-in permissions for this border';
        END IF;
        
        -- Check if pass has remaining entries
        IF v_pass_record.entries_remaining < 1 THEN
            RAISE EXCEPTION 'No entries remaining on pass';
        END IF;
        
    ELSIF v_previous_status = 'checked_in' THEN
        v_movement_type := 'check_out';
        v_new_status := 'checked_out';
        v_entries_deducted := 0;
        
        -- Check if official can perform check-out
        IF NOT v_can_check_out THEN
            RAISE EXCEPTION 'Official does not have check-out permissions for this border';
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Invalid pass status for movement: %', v_previous_status;
    END IF;
    
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
        entries_remaining = entries_remaining - v_entries_deducted,
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
        'entries_remaining', v_pass_record.entries_remaining - v_entries_deducted,
        'processed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- Create the supporting functions that are also referenced in the code

-- Function to check if official can process movement type
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
    v_can_check_in BOOLEAN := false;
    v_can_check_out BOOLEAN := false;
BEGIN
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RETURN false;
    END IF;
    
    SELECT can_check_in, can_check_out
    INTO v_can_check_in, v_can_check_out
    FROM border_official_borders
    WHERE profile_id = v_official_id 
      AND border_id = p_border_id 
      AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    IF p_movement_type = 'check_in' THEN
        RETURN v_can_check_in;
    ELSIF p_movement_type = 'check_out' THEN
        RETURN v_can_check_out;
    ELSE
        RETURN false;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION can_official_process_movement TO authenticated;

-- Function to get pass movement history
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
    -- Check if user can access this pass
    IF NOT EXISTS (
        SELECT 1 FROM purchased_passes 
        WHERE id = p_pass_id 
        AND (
            profile_id = auth.uid() -- Pass owner
            OR EXISTS ( -- Or border official who processed movements
                SELECT 1 FROM pass_movements pm
                WHERE pm.pass_id = p_pass_id 
                AND pm.official_id = auth.uid()
            )
        )
    ) THEN
        RAISE EXCEPTION 'Access denied to pass movement history';
    END IF;
    
    RETURN QUERY
    SELECT 
        pm.id as movement_id,
        b.name as border_name,
        p.full_name as official_name,
        pm.movement_type,
        pm.latitude,
        pm.longitude,
        pm.processed_at,
        pm.entries_deducted,
        pm.previous_status,
        pm.new_status
    FROM pass_movements pm
    JOIN borders b ON pm.border_id = b.id
    JOIN profiles p ON pm.official_id = p.id
    WHERE pm.pass_id = p_pass_id
    ORDER BY pm.processed_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_pass_movement_history TO authenticated;

-- Add comments for documentation
COMMENT ON FUNCTION process_pass_movement IS 'Processes pass check-in/check-out movements at borders';
COMMENT ON FUNCTION can_official_process_movement IS 'Checks if current official can process specific movement type at border';
COMMENT ON FUNCTION get_pass_movement_history IS 'Returns movement history for a specific pass';
COMMENT ON TABLE pass_movements IS 'Stores all pass movement records (check-ins and check-outs)';