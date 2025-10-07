-- Create Complete Movement History Function
-- This function returns ALL movements for a pass including:
-- 1. Border control movements (check_in, check_out)
-- 2. Local authority scans (local_authority_scan)

-- ============================================================================
-- FUNCTION: get_pass_movement_history
-- Returns complete movement history including local authority scans
-- Drop existing function first to avoid return type conflicts
-- ============================================================================
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID) CASCADE;

CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id UUID)
RETURNS TABLE (
    movement_id TEXT,
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
            OR EXISTS ( -- Or border official who can see movements
                SELECT 1 FROM pass_movements pm
                JOIN border_official_borders bob ON pm.border_id = bob.border_id
                WHERE pm.pass_id = p_pass_id 
                AND bob.profile_id = auth.uid()
                AND bob.is_active = true
            )
        )
    ) THEN
        RAISE EXCEPTION 'Access denied to pass movement history';
    END IF;

    -- Return movement history including local authority scans
    RETURN QUERY
    SELECT 
        pm.id::TEXT as movement_id,
        CASE 
            WHEN pm.authority_type = 'local_authority' THEN 'Local Authority'
            ELSE COALESCE(b.name, 'Unknown Border')
        END as border_name,
        COALESCE(p.full_name, 'Unknown Official') as official_name,
        pm.movement_type,
        pm.latitude,
        pm.longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    LEFT JOIN profiles p ON pm.profile_id = p.id
    WHERE pm.pass_id = p_pass_id
    ORDER BY pm.processed_at DESC;
END;
$$;

-- ============================================================================
-- FUNCTION: get_pass_history (alternative name for compatibility)
-- Same function with different name for fallback compatibility
-- Drop existing function first to avoid return type conflicts
-- ============================================================================
DROP FUNCTION IF EXISTS get_pass_history(UUID) CASCADE;

CREATE OR REPLACE FUNCTION get_pass_history(p_pass_id UUID)
RETURNS TABLE (
    id TEXT,
    border_name TEXT,
    official_name TEXT,
    action_type TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    performed_at TIMESTAMP WITH TIME ZONE,
    entries_deducted INTEGER,
    previous_status TEXT,
    new_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.id::TEXT as id,
        CASE 
            WHEN pm.authority_type = 'local_authority' THEN 'Local Authority'
            ELSE COALESCE(b.name, 'Unknown Border')
        END as border_name,
        COALESCE(p.full_name, 'Unknown Official') as official_name,
        pm.movement_type as action_type,
        pm.latitude,
        pm.longitude,
        pm.processed_at as performed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    LEFT JOIN profiles p ON pm.profile_id = p.id
    WHERE pm.pass_id = p_pass_id
    ORDER BY pm.processed_at DESC;
END;
$$;

-- ============================================================================
-- Grant permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION get_pass_movement_history(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_history(UUID) TO authenticated;

-- ============================================================================
-- Add documentation
-- ============================================================================
COMMENT ON FUNCTION get_pass_movement_history(UUID) IS 
'Returns complete movement history for a pass including border control movements and local authority scans';

COMMENT ON FUNCTION get_pass_history(UUID) IS 
'Alternative name for get_pass_movement_history - returns complete movement history including all scan types';

-- ============================================================================
-- Test the function
-- ============================================================================
DO $$
DECLARE
    test_pass_id UUID;
    movement_count INTEGER;
BEGIN
    -- Try to find a pass with movements to test
    SELECT pm.pass_id INTO test_pass_id
    FROM pass_movements pm
    LIMIT 1;
    
    IF test_pass_id IS NOT NULL THEN
        SELECT COUNT(*) INTO movement_count
        FROM get_pass_movement_history(test_pass_id);
        
        RAISE NOTICE '✅ Movement history functions created successfully!';
        RAISE NOTICE '   - Test pass % has % movement records', test_pass_id, movement_count;
        RAISE NOTICE '   - Functions include both border control and local authority scans';
        RAISE NOTICE '';
        RAISE NOTICE '📋 Available functions:';
        RAISE NOTICE '   1. get_pass_movement_history(pass_id) - Main function';
        RAISE NOTICE '   2. get_pass_history(pass_id) - Alternative name for compatibility';
    ELSE
        RAISE NOTICE '✅ Movement history functions created successfully!';
        RAISE NOTICE '   - No test data available, but functions are ready';
        RAISE NOTICE '   - Functions will include both border control and local authority scans';
    END IF;
END $$;