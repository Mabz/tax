-- Fix real-time subscription for secure code updates
-- Since columns already exist, we just need to ensure real-time works properly

-- ============================================================================
-- STEP 1: Ensure Real-time is Properly Configured
-- ============================================================================

-- Set replica identity to FULL for purchased_passes to ensure all columns are included in real-time updates
ALTER TABLE purchased_passes REPLICA IDENTITY FULL;

-- ============================================================================
-- STEP 2: Create/Update Real-time Trigger
-- ============================================================================

-- Create or replace trigger function for real-time notifications
CREATE OR REPLACE FUNCTION notify_pass_update()
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

-- Recreate the trigger to ensure it's working
DROP TRIGGER IF EXISTS trigger_pass_update ON purchased_passes;
CREATE TRIGGER trigger_pass_update
    BEFORE UPDATE ON purchased_passes
    FOR EACH ROW
    EXECUTE FUNCTION notify_pass_update();

-- ============================================================================
-- STEP 3: Test Real-time Updates
-- ============================================================================

-- Function to test real-time updates by updating a pass
CREATE OR REPLACE FUNCTION test_realtime_update(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_old_secure_code TEXT;
    v_new_secure_code TEXT;
BEGIN
    -- Get current secure code
    SELECT secure_code INTO v_old_secure_code
    FROM purchased_passes
    WHERE id = p_pass_id;
    
    -- Generate new secure code
    v_new_secure_code := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    
    -- Update the pass (this should trigger real-time notification)
    UPDATE purchased_passes
    SET 
        secure_code = v_new_secure_code,
        secure_code_expires_at = NOW() + INTERVAL '15 minutes',
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'pass_id', p_pass_id,
        'old_secure_code', v_old_secure_code,
        'new_secure_code', v_new_secure_code,
        'message', 'Real-time update triggered'
    );
END;
$;

-- Function to manually trigger a simple update for testing
CREATE OR REPLACE FUNCTION trigger_realtime_test(p_pass_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
    -- Simple update to trigger real-time notification
    UPDATE purchased_passes
    SET updated_at = NOW()
    WHERE id = p_pass_id;
    
    RETURN 'Real-time update triggered for pass: ' || p_pass_id;
END;
$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION test_realtime_update TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_realtime_test TO authenticated;

-- ============================================================================
-- STEP 4: Check Current Configuration
-- ============================================================================

-- Check if real-time is enabled (this will show current settings)
SELECT 
    'REPLICA IDENTITY CHECK' as section,
    schemaname,
    tablename,
    CASE 
        WHEN relreplident = 'd' THEN 'DEFAULT (primary key only)'
        WHEN relreplident = 'n' THEN 'NOTHING'
        WHEN relreplident = 'f' THEN 'FULL (all columns)'
        WHEN relreplident = 'i' THEN 'INDEX'
        ELSE 'UNKNOWN'
    END as replica_identity
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_tables t ON t.tablename = c.relname AND t.schemaname = n.nspname
WHERE c.relname = 'purchased_passes'
AND n.nspname = 'public';

-- Show current secure codes
SELECT 
    'CURRENT SECURE CODES' as section,
    id,
    profile_id,
    secure_code,
    secure_code_expires_at,
    CASE 
        WHEN secure_code_expires_at > NOW() THEN 'VALID'
        WHEN secure_code_expires_at <= NOW() THEN 'EXPIRED'
        ELSE 'NO_EXPIRY'
    END as status,
    updated_at
FROM purchased_passes
WHERE secure_code IS NOT NULL
ORDER BY updated_at DESC
LIMIT 5;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Real-time Configuration Updated!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Changes made:';
    RAISE NOTICE '- Set REPLICA IDENTITY FULL for purchased_passes';
    RAISE NOTICE '- Updated trigger function for better real-time notifications';
    RAISE NOTICE '- Created test functions for real-time updates';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'To test real-time updates:';
    RAISE NOTICE '1. Open Flutter app and go to "My Passes" screen';
    RAISE NOTICE '2. Run: SELECT test_realtime_update(''your-pass-id'');';
    RAISE NOTICE '3. Watch for automatic updates in the app';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'If real-time still doesn''t work, check:';
    RAISE NOTICE '- Supabase project settings (Real-time enabled)';
    RAISE NOTICE '- Flutter app real-time subscription setup';
    RAISE NOTICE '- Network connectivity';
    RAISE NOTICE '=================================================================';
END $;