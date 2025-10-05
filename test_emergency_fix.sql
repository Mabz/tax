-- Test the emergency fix for pass processing
-- Run this after running emergency_fix_pass_processing.sql

-- Check the current state of the audit table
SELECT 
    'AUDIT TABLE STATUS' as section,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'pass_processing_audit' 
            AND table_schema = 'public'
        ) THEN 'EXISTS'
        ELSE 'MISSING'
    END as table_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'pass_processing_audit' 
            AND column_name = 'action_type'
            AND table_schema = 'public'
        ) THEN 'HAS_ACTION_TYPE'
        ELSE 'MISSING_ACTION_TYPE'
    END as action_type_status;

-- Show available passes for testing
SELECT 
    'AVAILABLE PASSES' as section,
    id,
    pass_description,
    current_status,
    entries_remaining,
    secure_code
FROM purchased_passes 
WHERE status = 'active' 
AND expires_at > NOW()
AND entries_remaining > 0
ORDER BY created_at DESC
LIMIT 3;

-- Show available borders
SELECT 
    'AVAILABLE BORDERS' as section,
    id,
    name
FROM borders 
LIMIT 3;

-- Test the fixed function
DO $
DECLARE
    v_test_pass_id UUID;
    v_test_border_id UUID;
    v_result JSONB;
    v_old_secure_code TEXT;
    v_new_secure_code TEXT;
BEGIN
    -- Get test data
    SELECT id INTO v_test_pass_id
    FROM purchased_passes
    WHERE status = 'active' 
    AND expires_at > NOW()
    AND entries_remaining > 0
    LIMIT 1;
    
    SELECT id INTO v_test_border_id
    FROM borders 
    LIMIT 1;
    
    IF v_test_pass_id IS NOT NULL AND v_test_border_id IS NOT NULL THEN
        -- Get current secure code
        SELECT secure_code INTO v_old_secure_code
        FROM purchased_passes
        WHERE id = v_test_pass_id;
        
        RAISE NOTICE 'Testing pass processing...';
        RAISE NOTICE 'Pass ID: %', v_test_pass_id;
        RAISE NOTICE 'Border ID: %', v_test_border_id;
        RAISE NOTICE 'Old secure code: %', COALESCE(v_old_secure_code, 'NULL');
        
        -- Test the function
        SELECT process_pass_movement(
            v_test_pass_id,
            v_test_border_id,
            NULL, -- latitude
            NULL, -- longitude
            jsonb_build_object('test', true, 'emergency_fix', true)
        ) INTO v_result;
        
        RAISE NOTICE 'Processing result: %', v_result;
        
        -- Check the updated pass
        SELECT secure_code INTO v_new_secure_code
        FROM purchased_passes
        WHERE id = v_test_pass_id;
        
        RAISE NOTICE 'New secure code: %', COALESCE(v_new_secure_code, 'NULL');
        
        IF v_result->>'success' = 'true' THEN
            RAISE NOTICE '✅ SUCCESS: Pass processing worked without errors!';
            IF v_new_secure_code IS NOT NULL AND v_new_secure_code != v_old_secure_code THEN
                RAISE NOTICE '✅ SUCCESS: Secure code was generated!';
            ELSE
                RAISE NOTICE '⚠️  WARNING: Secure code was not generated';
            END IF;
        ELSE
            RAISE NOTICE '❌ FAILED: Pass processing returned failure';
        END IF;
        
    ELSE
        RAISE NOTICE 'No suitable test data found (need active pass with entries and a border)';
    END IF;
END $;

-- Final status check
DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'EMERGENCY FIX TEST COMPLETE';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'If you see "SUCCESS" messages above, the fix is working!';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Try Border Control pass scanning in your app';
    RAISE NOTICE '2. It should work without the audit table error';
    RAISE NOTICE '3. Secure codes should be generated automatically';
    RAISE NOTICE '4. Secure codes should appear in "My Passes" in real-time';
    RAISE NOTICE '=================================================================';
END $;