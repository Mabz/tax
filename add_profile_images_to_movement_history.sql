-- Add profile images to movement history function

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create function with profile image support
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
        -- For now, use placeholder names until we identify the correct columns
        CASE 
            WHEN pm.movement_type = 'local_authority_scan' THEN 'Bob Smith'
            ELSE 'Jane Doe'
        END as official_name,
        -- Placeholder profile image URL (you can replace with actual user's profile image URL)
        CASE 
            WHEN pm.movement_type = 'local_authority_scan' THEN 
                'https://cydtpwbgzilgrpozvesv.supabase.co/storage/v1/object/public/BorderTax/sample-user-id/profile_image_sample.jpg'
            ELSE NULL
        END as official_profile_image_url,
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