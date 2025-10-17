-- Debug Border Processing Issue
-- This script will help identify why entries aren't being deducted properly

-- 1. Check the current pass data
DO $$
DECLARE
    test_pass_id UUID := '2a9fe188-b6c9-4d83-90e0-48a71f24b3b5'; -- From your log
    pass_data RECORD;
    movement_count INTEGER;
BEGIN
    RAISE NOTICE '🔍 ========== DEBUGGING BORDER PROCESSING ISSUE ==========';
    
    -- Get current pass data
    SELECT * INTO pass_data
    FROM purchased_passes 
    WHERE id = test_pass_id;
    
    IF FOUND THEN
        RAISE NOTICE '📋 Pass Data:';
        RAISE NOTICE '   - Pass ID: %', pass_data.id;
        RAISE NOTICE '   - Current Status: %', pass_data.current_status;
        RAISE NOTICE '   - Entries Remaining: %', pass_data.entries_remaining;
        RAISE NOTICE '   - Entry Limit: %', pass_data.entry_limit;
        RAISE NOTICE '   - Status: %', pass_data.status;
        RAISE NOTICE '   - Expires At: %', pass_data.expires_at;
        
        -- Check movement history
        SELECT COUNT(*) INTO movement_count
        FROM pass_movements 
        WHERE pass_id = test_pass_id;
        
        RAISE NOTICE '📊 Movement History Count: %', movement_count;
        
        -- Show recent movements
        RAISE NOTICE '📋 Recent Movements:';
        FOR pass_data IN 
            SELECT 
                movement_type,
                previous_status,
                new_status,
                entries_deducted,
                processed_at,
                authority_type
            FROM pass_movements 
            WHERE pass_id = test_pass_id
            ORDER BY processed_at DESC
            LIMIT 5
        LOOP
            RAISE NOTICE '   - % | % -> % | Deducted: % | At: % | Authority: %', 
                pass_data.movement_type,
                pass_data.previous_status,
                pass_data.new_status,
                pass_data.entries_deducted,
                pass_data.processed_at,
                pass_data.authority_type;
        END LOOP;
        
    ELSE
        RAISE NOTICE '❌ Pass not found: %', test_pass_id;
    END IF;
    
    RAISE NOTICE '🔍 ========== END DEBUG ==========';
END $$;

-- 2. Check if there are multiple versions of the process_pass_movement function
SELECT 
    p.proname as function_name,
    p.pronargs as num_args,
    pg_get_function_arguments(p.oid) as arguments,
    p.prosrc LIKE '%entries_remaining%' as updates_entries
FROM pg_proc p
WHERE p.proname = 'process_pass_movement'
ORDER BY p.oid;

-- 3. Test the function logic with a sample call (without actually executing)
CREATE OR REPLACE FUNCTION test_border_processing_logic(
    p_pass_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_pass_record RECORD;
    v_movement_type TEXT;
    v_previous_status TEXT;
    v_new_status TEXT;
    v_entries_to_deduct INTEGER := 0;
BEGIN
    -- Get pass details
    SELECT * INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Pass not found');
    END IF;

    -- Determine movement type based on current status
    IF v_pass_record.current_status = 'active' OR v_pass_record.current_status = 'unused' THEN
        v_movement_type := 'check_in';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'in_transit';
        v_entries_to_deduct := 1;
        
    ELSIF v_pass_record.current_status = 'in_transit' THEN
        v_movement_type := 'check_out';
        v_previous_status := 'in_transit';
        v_new_status := 'active';
        v_entries_to_deduct := 0;
        
    ELSE
        v_movement_type := 'invalid';
        v_previous_status := v_pass_record.current_status;
        v_new_status := 'unchanged';
        v_entries_to_deduct := 0;
    END IF;

    RETURN jsonb_build_object(
        'current_status', v_pass_record.current_status,
        'entries_remaining', v_pass_record.entries_remaining,
        'determined_movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_to_deduct', v_entries_to_deduct,
        'would_have_sufficient_entries', (v_pass_record.entries_remaining >= v_entries_to_deduct)
    );
END;
$$;

-- Test with the problematic pass
SELECT test_border_processing_logic('2a9fe188-b6c9-4d83-90e0-48a71f24b3b5') as logic_test;

-- 4. Check if there are any triggers or other functions affecting the pass
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'purchased_passes';

-- 5. Check current status values in the database
SELECT 
    current_status,
    COUNT(*) as count
FROM purchased_passes 
GROUP BY current_status
ORDER BY count DESC;

-- Clean up test function
DROP FUNCTION IF EXISTS test_border_processing_logic(UUID);