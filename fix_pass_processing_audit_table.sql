-- Fix pass_processing_audit table schema
-- This script creates or fixes the pass_processing_audit table with correct columns

-- ============================================================================
-- STEP 1: Create or Fix pass_processing_audit Table
-- ============================================================================

-- Drop and recreate the table to ensure correct schema
DROP TABLE IF EXISTS pass_processing_audit CASCADE;

CREATE TABLE pass_processing_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_id UUID NOT NULL,
    action_type TEXT NOT NULL, -- This was missing!
    performed_by UUID,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    previous_status TEXT,
    new_status TEXT,
    entries_deducted INTEGER DEFAULT 0,
    entries_remaining INTEGER,
    border_id UUID,
    border_name TEXT,
    official_name TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign key constraints
ALTER TABLE pass_processing_audit 
ADD CONSTRAINT fk_pass_processing_audit_pass_id 
FOREIGN KEY (pass_id) REFERENCES purchased_passes(id) ON DELETE CASCADE;

-- Add indexes for performance
CREATE INDEX idx_pass_processing_audit_pass_id ON pass_processing_audit(pass_id);
CREATE INDEX idx_pass_processing_audit_performed_at ON pass_processing_audit(performed_at);
CREATE INDEX idx_pass_processing_audit_performed_by ON pass_processing_audit(performed_by);
CREATE INDEX idx_pass_processing_audit_action_type ON pass_processing_audit(action_type);

-- Enable RLS
ALTER TABLE pass_processing_audit ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own pass audit logs" ON pass_processing_audit
    FOR SELECT USING (
        pass_id IN (
            SELECT id FROM purchased_passes WHERE profile_id = auth.uid()
        )
    );
    
CREATE POLICY "Border officials can insert audit logs" ON pass_processing_audit
    FOR INSERT WITH CHECK (performed_by = auth.uid());

-- ============================================================================
-- STEP 2: Update process_pass_movement Function
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
AS $
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
    v_secure_code_result JSONB;
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
    
    -- Create audit log entry with correct column names
    INSERT INTO pass_processing_audit (
        pass_id,
        action_type,  -- This is the column that was missing!
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
    
    -- Update the pass status and entries
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Generate secure code for the pass owner (15-minute expiry)
    BEGIN
        -- Generate a 3-digit secure code
        v_secure_code_result := jsonb_build_object(
            'secure_code', LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0'),
            'expires_at', NOW() + INTERVAL '15 minutes'
        );
        
        -- Update the pass with secure code
        UPDATE purchased_passes
        SET 
            secure_code = v_secure_code_result->>'secure_code',
            secure_code_expires_at = (v_secure_code_result->>'expires_at')::TIMESTAMP WITH TIME ZONE,
            updated_at = NOW()
        WHERE id = p_pass_id;
        
        v_secure_code_result := jsonb_build_object(
            'success', true,
            'secure_code', v_secure_code_result->>'secure_code',
            'expires_at', v_secure_code_result->>'expires_at'
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            -- If secure code generation fails, continue without it
            v_secure_code_result := jsonb_build_object('success', false, 'error', SQLERRM);
    END;
    
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
        'secure_code_generated', v_secure_code_result,
        'processed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$;

-- ============================================================================
-- STEP 3: Grant Permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- ============================================================================
-- STEP 4: Test the Fix
-- ============================================================================

-- Function to test pass processing
CREATE OR REPLACE FUNCTION test_pass_processing(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_border_id UUID;
    v_result JSONB;
BEGIN
    -- Get any border for testing
    SELECT id INTO v_border_id FROM borders LIMIT 1;
    
    IF v_border_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No borders found for testing'
        );
    END IF;
    
    -- Process the pass movement
    SELECT process_pass_movement(
        p_pass_id,
        v_border_id,
        NULL, -- latitude
        NULL, -- longitude
        jsonb_build_object('test', true)
    ) INTO v_result;
    
    RETURN v_result;
END;
$;

GRANT EXECUTE ON FUNCTION test_pass_processing TO authenticated;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Pass Processing Audit Table Fixed!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Fixed:';
    RAISE NOTICE '- Created pass_processing_audit table with correct schema';
    RAISE NOTICE '- Added missing action_type column';
    RAISE NOTICE '- Updated process_pass_movement function';
    RAISE NOTICE '- Added secure code generation to pass processing';
    RAISE NOTICE '- Created test function';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Pass processing should now work without errors!';
    RAISE NOTICE 'Secure codes will be generated automatically when passes are processed.';
    RAISE NOTICE '=================================================================';
END $;