-- Test with a hardcoded profile image URL to isolate the issue

-- First, let's get your actual profile image URL
SELECT profile_image_url FROM profiles WHERE id = auth.uid();

-- Drop existing function and create test version with hardcoded URL
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);

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
        'Test User' as official_name,
        -- REPLACE THIS URL WITH YOUR ACTUAL PROFILE IMAGE URL FROM THE QUERY ABOVE
        'https://cydtpwbgzilgrpozvesv.supabase.co/storage/v1/object/public/BorderTax/cbf0f0a4-2d6d-4496-b944-f69c39aeecc2/profile_image_1759870571131.jpg' as official_profile_image_url,
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