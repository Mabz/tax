-- Test script to verify real-time secure code updates
-- Run this in Supabase SQL Editor to test the functionality

-- First, let's check if we have any active passes
SELECT 
    'ACTIVE PASSES' as section,
    id,
    profile_id,
    pass_description,
    secure_code,
    secure_code_expires_at,
    status
FROM purchased_passes 
WHERE status = 'active' 
AND expires_at > NOW()
ORDER BY created_at DESC
LIMIT 5;

-- Test 1: Generate a secure code for an active pass
DO $
DECLARE
    v_test_pass_id UUID;
    v_result JSONB;
BEGIN
    -- Get the first active pass
    SELECT id INTO v_test_pass_id
    FROM purchased_passes
    WHERE status = 'active' 
    AND expires_at > NOW()
    LIMIT 1;
    
    IF v_test_pass_id IS NOT NULL THEN
        -- Generate secure code
        SELECT generate_secure_code_for_pass(v_test_pass_id, 15) INTO v_result;
        
        RAISE NOTICE 'Test 1 - Generated secure code for pass %: %', v_test_pass_id, v_result;
        
        -- Wait a moment then check the pass
        PERFORM pg_sleep(1);
        
        -- Show the updated pass
        RAISE NOTICE 'Updated pass data:';
        FOR v_result IN 
            SELECT jsonb_build_object(
                'id', id,
                'secure_code', secure_code,
                'expires_at', secure_code_expires_at
            ) as pass_data
            FROM purchased_passes 
            WHERE id = v_test_pass_id
        LOOP
            RAISE NOTICE 'Pass: %', v_result;
        END LOOP;
    ELSE
        RAISE NOTICE 'No active passes found for testing';
    END IF;
END $;

-- Test 2: Update a pass to trigger real-time notification
DO $
DECLARE
    v_test_pass_id UUID;
BEGIN
    -- Get the first active pass
    SELECT id INTO v_test_pass_id
    FROM purchased_passes
    WHERE status = 'active' 
    AND expires_at > NOW()
    LIMIT 1;
    
    IF v_test_pass_id IS NOT NULL THEN
        RAISE NOTICE 'Test 2 - Updating pass % to trigger real-time notification', v_test_pass_id;
        
        -- Update the pass (this should trigger real-time notification)
        UPDATE purchased_passes 
        SET updated_at = NOW()
        WHERE id = v_test_pass_id;
        
        RAISE NOTICE 'Pass updated successfully';
    END IF;
END $;

-- Test 3: Check current secure codes
SELECT 
    'CURRENT SECURE CODES' as section,
    id,
    secure_code,
    secure_code_expires_at,
    CASE 
        WHEN secure_code_expires_at IS NOT NULL AND secure_code_expires_at > NOW() THEN 'VALID'
        WHEN secure_code_expires_at IS NOT NULL AND secure_code_expires_at <= NOW() THEN 'EXPIRED'
        ELSE 'NONE'
    END as status,
    CASE 
        WHEN secure_code_expires_at IS NOT NULL THEN
            EXTRACT(EPOCH FROM (secure_code_expires_at - NOW())) / 60
        ELSE 0
    END as minutes_remaining
FROM purchased_passes
WHERE secure_code IS NOT NULL
ORDER BY secure_code_expires_at DESC NULLS LAST;

-- Instructions for testing
DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'REAL-TIME TESTING INSTRUCTIONS';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '1. Open your Flutter app and go to "My Passes" screen';
    RAISE NOTICE '2. Keep the app open and visible';
    RAISE NOTICE '3. Run this command to generate a secure code:';
    RAISE NOTICE '   SELECT manual_generate_secure_code(''your-pass-id-here'');';
    RAISE NOTICE '4. Watch the app - the secure code should appear automatically';
    RAISE NOTICE '5. If it doesn''t appear, check the Flutter console for debug logs';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Debug commands:';
    RAISE NOTICE '- Check secure codes: SELECT * FROM check_secure_codes();';
    RAISE NOTICE '- Test functionality: SELECT test_secure_code_functionality();';
    RAISE NOTICE '=================================================================';
END $;