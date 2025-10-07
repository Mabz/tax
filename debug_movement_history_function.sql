-- Debug version of movement history function with detailed logging

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create debug version that shows exactly what's happening
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
DECLARE
    current_user_id UUID;
    current_user_name TEXT;
    current_user_image_url TEXT;
BEGIN
    -- Get current user info for debugging
    current_user_id := auth.uid();
    
    SELECT full_name INTO current_user_name 
    FROM profiles WHERE id = current_user_id;
    
    SELECT profile_image_url INTO current_user_image_url 
    FROM profiles WHERE id = current_user_id;
    
    -- Log debug info (this will show in Supabase logs)
    RAISE NOTICE 'Debug: Current user ID: %', current_user_id;
    RAISE NOTICE 'Debug: Current user name: %', current_user_name;
    RAISE NOTICE 'Debug: Current user image URL: %', current_user_image_url;
    
    RETURN QUERY
    SELECT 
        pm.id::TEXT as movement_id,
        COALESCE(b.name, 'Local Authority') as border_name,
        COALESCE(current_user_name, 'Debug User') as official_name,
        current_user_image_url as official_profile_image_url,
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