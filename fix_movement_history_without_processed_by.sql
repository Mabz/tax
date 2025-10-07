-- Fix movement history function without assuming processed_by column exists

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create a simplified function that works with existing table structure
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
        COALESCE(
            CASE 
                WHEN pm.official_id IS NOT NULL THEN p1.full_name
                WHEN pm.scanned_by IS NOT NULL THEN p2.full_name
                ELSE 'Unknown Official'
            END, 
            'Unknown Official'
        ) as official_name,
        COALESCE(
            CASE 
                WHEN pm.official_id IS NOT NULL THEN p1.profile_image_url
                WHEN pm.scanned_by IS NOT NULL THEN p2.profile_image_url
                ELSE NULL
            END
        ) as official_profile_image_url,
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
    LEFT JOIN profiles p1 ON pm.official_id = p1.id
    LEFT JOIN profiles p2 ON pm.scanned_by = p2.id
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;