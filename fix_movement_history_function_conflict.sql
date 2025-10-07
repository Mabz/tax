-- Fix function overloading conflict for get_pass_movement_history

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create a single, properly defined function that accepts TEXT and converts to UUID
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
        COALESCE(p.full_name, 'Unknown Official') as official_name,
        p.profile_image_url as official_profile_image_url,
        pm.movement_type,
        pm.latitude,
        pm.longitude,
        pm.processed_at,
        pm.entries_deducted,
        pm.previous_status,
        pm.new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    LEFT JOIN profiles p ON pm.processed_by = p.id
    LEFT JOIN authorities a ON pm.authority_id = a.id
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;