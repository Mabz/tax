-- Test the pass processing fix
-- Run this after running fix_pass_processing_audit_table.sql

-- Check if the audit table was created correctly
SELECT 
    'AUDIT TABLE COLUMNS' as section,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'pass_processing_audit' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if we have any active passes to test with
SELECT 
    'ACTIVE PASSES FOR TESTING' as section,
    id,
    profile_id,
    pass_description,
    current_status,
    entries_remaining,
    secure_code
FROM purchased_passes 
WHERE status = 'active' 
AND expires_at > NOW()
ORDER BY created_at DESC
LIMIT 3;

-- Check if we have borders for testing
SELECT 
    'AVAILABLE BORDERS' as section,
    id,
    name
FROM borders 
LIMIT 3;

-- Test function to simulate pass processing
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
    AND entries_remaining > 0
    LIMIT 1;
    
    IF v_test_pass_id IS NOT NULL THEN
        RAISE NOTICE 'Testing pass processing with pass: %', v_test_pass_id;
        
        -- Test the pass processing function
        SELECT test_pass_processing(v_test_pass_id) INTO v_result;
        
        RAISE NOTICE 'Pass processing result: %', v_result;
        
        -- Check if secure code was generated
        SELECT jsonb_build_object(
            'pass_id', id,
            'secure_code', secure_code,
            'expires_at', secure_code_expires_at,
            'current_status', current_status
        ) INTO v_result
        FROM purchased_passes 
        WHERE id = v_test_pass_id;
        
        RAISE NOTICE 'Updated pass data: %', v_result;
        
    ELSE
        RAISE NOTICE 'No active passes with remaining entries found for testing';
    END IF;
END $;

-- Instructions
DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'PASS PROCESSING TEST COMPLETE';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'If you see no errors above, the fix is working!';
    RAISE NOTICE '';
    RAISE NOTICE 'To test in your app:';
    RAISE NOTICE '1. Try scanning a pass in Border Control';
    RAISE NOTICE '2. The processing should now work without errors';
    RAISE NOTICE '3. A secure code should be generated automatically';
    RAISE NOTICE '4. The secure code should appear in "My Passes" in real-time';
    RAISE NOTICE '=================================================================';
END $;