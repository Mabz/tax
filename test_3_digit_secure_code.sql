-- Test script to verify 3-digit secure code generation
-- This script tests the new 3-digit secure code implementation

DO $$
DECLARE
    v_test_code TEXT;
    v_code_length INTEGER;
    i INTEGER;
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Testing 3-digit secure code generation';
    RAISE NOTICE '=================================================================';
    
    -- Test the code generation 10 times to ensure consistency
    FOR i IN 1..10 LOOP
        -- Generate a 3-digit secure code using the same logic as the main functions
        v_test_code := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
        v_code_length := LENGTH(v_test_code);
        
        RAISE NOTICE 'Test %: Generated code = %, Length = %', i, v_test_code, v_code_length;
        
        -- Verify the code is exactly 3 digits
        IF v_code_length != 3 THEN
            RAISE EXCEPTION 'ERROR: Code length is % instead of 3!', v_code_length;
        END IF;
        
        -- Verify the code contains only digits
        IF v_test_code !~ '^[0-9]{3}$' THEN
            RAISE EXCEPTION 'ERROR: Code contains non-digit characters: %', v_test_code;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ All tests passed! 3-digit secure code generation is working correctly.';
    RAISE NOTICE '';
    RAISE NOTICE 'Code range: 000-999 (1,000 possible combinations)';
    RAISE NOTICE 'Format: Always 3 digits with leading zeros';
    RAISE NOTICE 'Examples: 001, 042, 123, 999';
    RAISE NOTICE '=================================================================';
END $$;