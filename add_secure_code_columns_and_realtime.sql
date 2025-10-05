-- Add secure code columns and ensure real-time updates work
-- This script adds the missing secure_code columns and sets up real-time functionality

-- ============================================================================
-- STEP 1: Add Missing Secure Code Columns
-- ============================================================================

DO $
BEGIN
    -- Add secure_code column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'secure_code'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN secure_code TEXT;
        COMMENT ON COLUMN purchased_passes.secure_code IS 'Temporary secure code for border verification';
        RAISE NOTICE 'Added secure_code column to purchased_passes';
    ELSE
        RAISE NOTICE 'secure_code column already exists';
    END IF;
    
    -- Add secure_code_expires_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'secure_code_expires_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN secure_code_expires_at TIMESTAMP WITH TIME ZONE;
        COMMENT ON COLUMN purchased_passes.secure_code_expires_at IS 'Expiration time for the secure code';
        RAISE NOTICE 'Added secure_code_expires_at column to purchased_passes';
    ELSE
        RAISE NOTICE 'secure_code_expires_at column already exists';
    END IF;
END $;

-- ============================================================================
-- STEP 2: Ensure Real-time Updates are Properly Configured
-- ============================================================================

-- Set replica identity to FULL for purchased_passes to ensure all columns are included in real-time updates
ALTER TABLE purchased_passes REPLICA IDENTITY FULL;

-- Create or replace function to generate secure codes
CREATE OR REPLACE FUNCTION generate_secure_code_for_pass(
    p_pass_id UUID,
    p_expiry_minutes INTEGER DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_secure_code TEXT;
    v_expires_at TIMESTAMP WITH TIME ZONE;
    v_pass_exists BOOLEAN;
BEGIN
    -- Check if pass exists and is active
    SELECT EXISTS(
        SELECT 1 FROM purchased_passes 
        WHERE id = p_pass_id 
        AND status = 'active' 
        AND expires_at > NOW()
    ) INTO v_pass_exists;
    
    IF NOT v_pass_exists THEN
        RAISE EXCEPTION 'Pass not found or not active';
    END IF;
    
    -- Generate a 3-digit secure code
    v_secure_code := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    v_expires_at := NOW() + INTERVAL '1 minute' * p_expiry_minutes;
    
    -- Update the pass with the secure code
    UPDATE purchased_passes
    SET 
        secure_code = v_secure_code,
        secure_code_expires_at = v_expires_at,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Return the result
    RETURN jsonb_build_object(
        'success', true,
        'secure_code', v_secure_code,
        'expires_at', v_expires_at,
        'expires_in_minutes', p_expiry_minutes
    );
END;
$;

-- Create or replace function to verify secure code
CREATE OR REPLACE FUNCTION verify_secure_code(
    p_pass_id UUID,
    p_secure_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_pass_record RECORD;
    v_is_valid BOOLEAN := false;
BEGIN
    -- Get the pass with secure code info
    SELECT 
        id,
        secure_code,
        secure_code_expires_at,
        status,
        expires_at
    INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Pass not found'
        );
    END IF;
    
    -- Check if pass is active
    IF v_pass_record.status != 'active' OR v_pass_record.expires_at <= NOW() THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Pass is not active or has expired'
        );
    END IF;
    
    -- Check if secure code exists and matches
    IF v_pass_record.secure_code IS NULL OR v_pass_record.secure_code != p_secure_code THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Invalid secure code'
        );
    END IF;
    
    -- Check if secure code has expired
    IF v_pass_record.secure_code_expires_at IS NULL OR v_pass_record.secure_code_expires_at <= NOW() THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Secure code has expired'
        );
    END IF;
    
    -- Clear the secure code after successful verification (one-time use)
    UPDATE purchased_passes
    SET 
        secure_code = NULL,
        secure_code_expires_at = NULL,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    RETURN jsonb_build_object(
        'valid', true,
        'message', 'Secure code verified successfully'
    );
END;
$;

-- Update the process_pass_movement function to generate secure codes
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
    
    -- Create audit log entry if table exists
    BEGIN
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
    EXCEPTION
        WHEN undefined_table THEN
            -- Audit table doesn't exist, continue without it
            v_audit_id := NULL;
    END;
    
    -- Update the pass status and entries
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Generate secure code for the pass owner (15-minute expiry)
    BEGIN
        SELECT generate_secure_code_for_pass(p_pass_id, 15) INTO v_secure_code_result;
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

GRANT EXECUTE ON FUNCTION generate_secure_code_for_pass TO authenticated;
GRANT EXECUTE ON FUNCTION verify_secure_code TO authenticated;
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;

-- ============================================================================
-- STEP 4: Create Real-time Trigger for Secure Code Updates
-- ============================================================================

-- Create or replace trigger function for real-time notifications
CREATE OR REPLACE FUNCTION notify_pass_secure_code_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $
BEGIN
    -- Ensure updated_at is set for real-time notifications
    NEW.updated_at = NOW();
    
    -- Log secure code changes for debugging
    IF OLD.secure_code IS DISTINCT FROM NEW.secure_code THEN
        RAISE NOTICE 'Secure code updated for pass %: % -> %', 
            NEW.id, 
            COALESCE(OLD.secure_code, 'NULL'), 
            COALESCE(NEW.secure_code, 'NULL');
    END IF;
    
    RETURN NEW;
END;
$;

-- Create the trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_pass_secure_code_update ON purchased_passes;
CREATE TRIGGER trigger_pass_secure_code_update
    BEFORE UPDATE ON purchased_passes
    FOR EACH ROW
    EXECUTE FUNCTION notify_pass_secure_code_update();

-- ============================================================================
-- STEP 5: Test Functions
-- ============================================================================

-- Create a test function to verify secure code functionality
CREATE OR REPLACE FUNCTION test_secure_code_functionality()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_test_pass_id UUID;
    v_result JSONB;
    v_secure_code TEXT;
BEGIN
    -- Find an active pass for testing
    SELECT id INTO v_test_pass_id
    FROM purchased_passes
    WHERE status = 'active' 
    AND expires_at > NOW()
    LIMIT 1;
    
    IF v_test_pass_id IS NULL THEN
        RETURN 'No active passes found for testing';
    END IF;
    
    -- Test secure code generation
    SELECT generate_secure_code_for_pass(v_test_pass_id, 5) INTO v_result;
    
    IF v_result->>'success' = 'true' THEN
        v_secure_code := v_result->>'secure_code';
        
        -- Test secure code verification
        SELECT verify_secure_code(v_test_pass_id, v_secure_code) INTO v_result;
        
        IF v_result->>'valid' = 'true' THEN
            RETURN 'Secure code functionality working correctly';
        ELSE
            RETURN 'Secure code verification failed: ' || (v_result->>'error');
        END IF;
    ELSE
        RETURN 'Secure code generation failed';
    END IF;
END;
$;

GRANT EXECUTE ON FUNCTION test_secure_code_functionality TO authenticated;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Secure Code System Setup Complete!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Added:';
    RAISE NOTICE '- secure_code column to purchased_passes';
    RAISE NOTICE '- secure_code_expires_at column to purchased_passes';
    RAISE NOTICE '- generate_secure_code_for_pass function';
    RAISE NOTICE '- verify_secure_code function';
    RAISE NOTICE '- Updated process_pass_movement to generate secure codes';
    RAISE NOTICE '- Real-time trigger for secure code updates';
    RAISE NOTICE '- Set REPLICA IDENTITY FULL for real-time updates';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'How it works:';
    RAISE NOTICE '1. Border control processes pass -> secure code generated';
    RAISE NOTICE '2. Pass owner sees secure code in real-time on My Passes screen';
    RAISE NOTICE '3. Secure code expires in 15 minutes';
    RAISE NOTICE '4. Code is cleared after successful verification';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Test the functionality by running: SELECT test_secure_code_functionality();';
    RAISE NOTICE '=================================================================';
END $;