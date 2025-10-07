-- Fix get_profile_by_email function to include profile_image_url

-- First, let's see the current function
-- SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'get_profile_by_email';

-- Drop and recreate the function with profile_image_url
DROP FUNCTION IF EXISTS get_profile_by_email(TEXT);

-- Create updated function that includes profile_image_url
CREATE OR REPLACE FUNCTION get_profile_by_email(p_email TEXT)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    email TEXT,
    profile_image_url TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.full_name,
        p.email,
        p.profile_image_url,
        p.is_active,
        p.created_at,
        p.updated_at
    FROM profiles p
    WHERE p.email = p_email;
END;
$$;