-- Get actual official profiles for movement history

-- First, let's check what columns exist in pass_movements that might link to profiles
-- Run this query to see the structure:
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'pass_movements' 
AND table_schema = 'public'
AND column_name LIKE '%id%'
ORDER BY column_name;

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create function that tries multiple possible column names for the official
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
    has_scanned_by BOOLEAN;
    has_official_id BOOLEAN;
    has_processed_by BOOLEAN;
    has_user_id BOOLEAN;
BEGIN
    -- Check which columns exist in pass_movements table
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'scanned_by'
    ) INTO has_scanned_by;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'official_id'
    ) INTO has_official_id;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'processed_by'
    ) INTO has_processed_by;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_movements' 
        AND column_name = 'user_id'
    ) INTO has_user_id;

    -- Build the query based on available columns
    IF has_scanned_by THEN
        RETURN QUERY
        SELECT 
            pm.id::TEXT as movement_id,
            COALESCE(b.name, 'Local Authority') as border_name,
            COALESCE(p.full_name, 'Unknown Official') as official_name,
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
        LEFT JOIN profiles p ON pm.scanned_by = p.id
        WHERE pm.pass_id = p_pass_id::UUID
        ORDER BY pm.processed_at DESC;
    ELSIF has_official_id THEN
        RETURN QUERY
        SELECT 
            pm.id::TEXT as movement_id,
            COALESCE(b.name, 'Local Authority') as border_name,
            COALESCE(p.full_name, 'Unknown Official') as official_name,
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
        LEFT JOIN profiles p ON pm.official_id = p.id
        WHERE pm.pass_id = p_pass_id::UUID
        ORDER BY pm.processed_at DESC;
    ELSIF has_processed_by THEN
        RETURN QUERY
        SELECT 
            pm.id::TEXT as movement_id,
            COALESCE(b.name, 'Local Authority') as border_name,
            COALESCE(p.full_name, 'Unknown Official') as official_name,
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
        LEFT JOIN profiles p ON pm.processed_by = p.id
        WHERE pm.pass_id = p_pass_id::UUID
        ORDER BY pm.processed_at DESC;
    ELSIF has_user_id THEN
        RETURN QUERY
        SELECT 
            pm.id::TEXT as movement_id,
            COALESCE(b.name, 'Local Authority') as border_name,
            COALESCE(p.full_name, 'Unknown Official') as official_name,
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
        LEFT JOIN profiles p ON pm.user_id = p.id
        WHERE pm.pass_id = p_pass_id::UUID
        ORDER BY pm.processed_at DESC;
    ELSE
        -- Fallback: no profile linking possible
        RETURN QUERY
        SELECT 
            pm.id::TEXT as movement_id,
            COALESCE(b.name, 'Local Authority') as border_name,
            'Unknown Official'::TEXT as official_name,
            NULL::TEXT as official_profile_image_url,
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
    END IF;
END;
$$;