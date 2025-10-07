-- Get both full_name and profile_image_url in exactly the same way

-- Drop existing function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);

-- Create function that gets both name and image URL in one query
CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id TEXT)
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,
    official_name TEXT,
    official_profile_image_url TEXT,
    movement_type TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    processed_at TIMESTAMP WITH TIME ZONE,
    entries_deducted INTEGER,
    previous_status TEXT,
    new_status TEXT,
    notes TEXT,
    scan_purpose TEXT,
    authority_type TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.id::TEXT as movement_id,
        COALESCE(b.name, 'Local Authority') as border_name,
        -- Get both name and image URL from the official who processed the movement
        COALESCE(p.full_name, 'Unknown User') as official_name,
        p.profile_image_url as official_profile_image_url,
        pm.movement_type,
        COALESCE(pm.latitude, 0.0) as latitude,
        COALESCE(pm.longitude, 0.0) as longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status,
        pm.notes,
        pm.scan_purpose,
        pm.authority_type
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    -- Join with profiles table to get the official's data who processed this movement
    LEFT JOIN profiles p ON p.id = pm.processed_by
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;