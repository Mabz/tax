-- Create function to log local authority scans in pass_movements table
-- This function should be run in your Supabase SQL editor

-- First, ensure pass_movements table exists with correct structure
CREATE TABLE IF NOT EXISTS pass_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_id UUID NOT NULL REFERENCES purchased_passes(id) ON DELETE CASCADE,
    border_id UUID REFERENCES borders(id) ON DELETE SET NULL,
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('check_in', 'check_out', 'local_authority_scan', 'verification_scan')),
    previous_status TEXT,
    new_status TEXT,
    entries_deducted INTEGER DEFAULT 0,
    latitude DECIMAL,
    longitude DECIMAL,
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_pass_movements_pass_id ON pass_movements(pass_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_profile_id ON pass_movements(profile_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_processed_at ON pass_movements(processed_at);
CREATE INDEX IF NOT EXISTS idx_pass_movements_movement_type ON pass_movements(movement_type);

-- Create the log_local_authority_scan function
CREATE OR REPLACE FUNCTION log_local_authority_scan(
    p_pass_id UUID,
    p_authority_type TEXT DEFAULT 'local_authority',
    p_scan_purpose TEXT DEFAULT 'verification_check',
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
    v_pass_status TEXT;
BEGIN
    -- Get current user (could be null for anonymous scans)
    v_current_user_id := auth.uid();
    
    -- Get current pass status
    SELECT current_status INTO v_pass_status 
    FROM purchased_passes 
    WHERE id = p_pass_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass not found: %', p_pass_id;
    END IF;
    
    -- Enhance metadata with scan information
    p_metadata := p_metadata || jsonb_build_object(
        'authority_type', p_authority_type,
        'scan_purpose', p_scan_purpose,
        'scan_timestamp', NOW(),
        'user_id', v_current_user_id
    );
    
    -- Insert the scan record into pass_movements
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
        CASE 
            WHEN p_authority_type = 'local_authority' THEN 'local_authority_scan'
            ELSE 'verification_scan'
        END,
        v_pass_status,
        v_pass_status, -- Status doesn't change for scans
        0, -- No entries deducted for scans
        p_latitude,
        p_longitude,
        p_notes,
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;
    
    -- Update pass last scanned timestamp (use a column that exists or add metadata)
    -- Note: If last_used_at doesn't exist, we'll skip this update or use metadata
    -- UPDATE purchased_passes 
    -- SET last_used_at = NOW()
    -- WHERE id = p_pass_id;
    
    RETURN v_movement_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION log_local_authority_scan TO authenticated;
GRANT EXECUTE ON FUNCTION log_local_authority_scan TO anon;

-- Add RLS policy for pass_movements if it doesn't exist
DO $$
BEGIN
    -- Enable RLS
    ALTER TABLE pass_movements ENABLE ROW LEVEL SECURITY;
    
    -- Policy for users to see their own pass movements
    CREATE POLICY "Users can view their own pass movements" ON pass_movements
        FOR SELECT USING (
            pass_id IN (
                SELECT id FROM purchased_passes WHERE profile_id = auth.uid()
            )
        );
    
    -- Policy for officials to see movements they processed
    CREATE POLICY "Officials can view movements they processed" ON pass_movements
        FOR SELECT USING (profile_id = auth.uid());
    
    -- Policy for inserting movements (authenticated users and anon for scans)
    CREATE POLICY "Allow movement logging" ON pass_movements
        FOR INSERT WITH CHECK (true);
        
EXCEPTION
    WHEN duplicate_object THEN
        -- Policies already exist, skip
        NULL;
END;
$$;

-- Test the function
SELECT 'log_local_authority_scan function created successfully' as status;

-- Add comment
COMMENT ON FUNCTION log_local_authority_scan IS 'Logs local authority scans in pass_movements table with GPS coordinates and metadata';