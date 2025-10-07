-- Update movement history function to include real official names

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create function that gets real official names from profiles
CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id TEXT)
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,
    official_name TEXT,
    movement_type TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
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
        COALESCE(
            -- Try different possible column names for the official
            CASE 
                WHEN pm.scanned_by IS NOT NULL THEN p1.full_name
                WHEN pm.official_id IS NOT NULL THEN p2.full_name
                WHEN pm.processed_by IS NOT NULL THEN p3.full_name
                WHEN pm.user_id IS NOT NULL THEN p4.full_name
                ELSE NULL
            END,
            'Unknown Official'
        ) as official_name,
        pm.movement_type,
        COALESCE(pm.latitude, 0.0) as latitude,
        COALESCE(pm.longitude, 0.0) as longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    LEFT JOIN profiles p1 ON pm.scanned_by = p1.id
    LEFT JOIN profiles p2 ON pm.official_id = p2.id
    LEFT JOIN profiles p3 ON pm.processed_by = p3.id
    LEFT JOIN profiles p4 ON pm.user_id = p4.id
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;