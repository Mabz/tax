-- Fix movement history function to use display names (simplified version)

DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

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
        -- Use display name from authority_profiles if available, fallback to full_name
        COALESCE(
            ap.display_name, 
            p.full_name, 
            'Unknown Official'
        ) as official_name,
        p.profile_image_url as official_profile_image_url,
        pm.movement_type,
        COALESCE(pm.latitude, 0.0) as latitude,
        COALESCE(pm.longitude, 0.0) as longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    LEFT JOIN profiles p ON pm.profile_id = p.id
    -- Join with authority_profiles to get display names
    -- We'll try to match based on the border's authority if available
    LEFT JOIN authority_profiles ap ON p.id = ap.profile_id 
        AND (
            -- If there's a border, use its authority_id
            (b.authority_id IS NOT NULL AND ap.authority_id = b.authority_id)
            OR
            -- If no border (local authority scan), try to find any active authority_profile for this user
            (b.authority_id IS NULL AND ap.is_active = true)
        )
        AND ap.is_active = true  -- Only use active authority profiles
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_pass_movement_history(TEXT) TO authenticated;