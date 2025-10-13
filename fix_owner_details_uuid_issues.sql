-- Fix UUID issues in owner details functions

-- Update get_owner_profile_for_authority to handle invalid UUIDs
CREATE OR REPLACE FUNCTION get_owner_profile_for_authority(
    owner_profile_id UUID
) RETURNS TABLE (
    id UUID,
    full_name TEXT,
    email TEXT,
    phone_number TEXT,
    address TEXT,
    country_of_origin_id UUID,
    national_id_number TEXT,
    passport_number TEXT,
    passport_document_url TEXT,
    profile_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    country_name TEXT,
    country_code TEXT
) AS $$
BEGIN
    -- Check if the current user is an authority user
    IF NOT EXISTS (
        SELECT 1 FROM authority_profiles 
        WHERE profile_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Only authority users can view owner details';
    END IF;

    -- Check if owner_profile_id is null
    IF owner_profile_id IS NULL THEN
        RAISE EXCEPTION 'Owner profile ID cannot be null';
    END IF;

    -- Return owner profile with country information
    RETURN QUERY
    SELECT 
        p.id,
        p.full_name,
        p.email,
        p.phone_number,
        p.address,
        p.country_of_origin_id,
        p.national_id_number,
        p.passport_number,
        p.passport_document_url,
        p.profile_image_url,
        p.created_at,
        p.updated_at,
        c.name as country_name,
        c.country_code
    FROM profiles p
    LEFT JOIN countries c ON c.id = p.country_of_origin_id
    WHERE p.id = owner_profile_id;

    -- If no results found, raise a more specific error
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Owner profile not found for ID: %', owner_profile_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_owner_identity_for_authority to handle invalid UUIDs
CREATE OR REPLACE FUNCTION get_owner_identity_for_authority(
    owner_profile_id UUID
) RETURNS TABLE (
    profile_id UUID,
    country_of_origin_id UUID,
    country_name TEXT,
    country_code TEXT,
    national_id_number TEXT,
    passport_number TEXT,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Check if the current user is an authority user
    IF NOT EXISTS (
        SELECT 1 FROM authority_profiles 
        WHERE profile_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Only authority users can view identity details';
    END IF;

    -- Check if owner_profile_id is null
    IF owner_profile_id IS NULL THEN
        RAISE EXCEPTION 'Owner profile ID cannot be null';
    END IF;

    -- Return identity information
    RETURN QUERY
    SELECT 
        p.id as profile_id,
        p.country_of_origin_id,
        c.name as country_name,
        c.country_code,
        p.national_id_number,
        p.passport_number,
        p.updated_at
    FROM profiles p
    LEFT JOIN countries c ON c.id = p.country_of_origin_id
    WHERE p.id = owner_profile_id;

    -- If no results found, that's okay for identity documents
    -- They might not have filled out their identity information yet
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_identity_documents_for_profile to handle invalid UUIDs
CREATE OR REPLACE FUNCTION get_identity_documents_for_profile(
    profile_id UUID
) RETURNS TABLE (
    country_of_origin_id UUID,
    country_name TEXT,
    country_code TEXT,
    national_id_number TEXT,
    passport_number TEXT,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Check if profile_id is null
    IF profile_id IS NULL THEN
        RAISE EXCEPTION 'Profile ID cannot be null';
    END IF;

    -- Return identity documents information
    RETURN QUERY
    SELECT 
        p.country_of_origin_id,
        c.name as country_name,
        c.country_code,
        p.national_id_number,
        p.passport_number,
        p.updated_at
    FROM profiles p
    LEFT JOIN countries c ON c.id = p.country_of_origin_id
    WHERE p.id = profile_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a helper function to validate UUID format
CREATE OR REPLACE FUNCTION is_valid_uuid(input_text TEXT) 
RETURNS BOOLEAN AS $$
BEGIN
    -- Try to cast to UUID, return false if it fails
    BEGIN
        PERFORM input_text::UUID;
        RETURN TRUE;
    EXCEPTION WHEN invalid_text_representation THEN
        RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_valid_uuid(TEXT) TO authenticated;