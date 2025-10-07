-- Fix data type mismatch in movement history function

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create function with correct data types that match the actual database
CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id TEXT)
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,
    official_name TEXT,
    movement_type TEXT,
    latitude NUMERIC,  -- Changed from DOUBLE PRECISION to NUMERIC
    longitude NUMERIC, -- Changed from DOUBLE PRECISION to NUMERIC
    processed_at TIMESTAMP WITH TIME ZONE,
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
        pm.id::TEXT as movement_id,
        COALESCE(b.name, 'Local Authority') as border_name,
        'Unknown Official'::TEXT as official_name,
        pm.movement_type,
        COALESCE(pm.latitude, 0.0) as latitude,
        COALESCE(pm.longitude, 0.0) as longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;