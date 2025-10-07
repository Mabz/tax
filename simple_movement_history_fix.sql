-- Simple movement history function that works with basic table structure

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create a basic function that returns the core data without profile joins
CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id TEXT)
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,
    official_name TEXT,
    official_profile_image_url TEXT,
    movement_type TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
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
        CASE 
            WHEN pm.movement_type = 'local_authority_scan' THEN 
                COALESCE(a.name, 'Local Authority')
            ELSE 
                COALESCE(b.name, 'Unknown Border')
        END as border_name,
        'Unknown Official'::TEXT as official_name,  -- Placeholder until we know the correct column
        NULL::TEXT as official_profile_image_url,   -- Placeholder for now
        pm.movement_type,
        COALESCE(pm.latitude, 0.0) as latitude,
        COALESCE(pm.longitude, 0.0) as longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    LEFT JOIN authorities a ON pm.authority_id = a.id
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;