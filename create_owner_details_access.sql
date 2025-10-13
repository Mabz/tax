-- Create function for authorities to get owner profile details
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get owner identity documents for authorities
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get vehicle owner from pass ID
CREATE OR REPLACE FUNCTION get_pass_owner_details(
    pass_id UUID
) RETURNS TABLE (
    owner_id UUID,
    owner_name TEXT,
    owner_email TEXT,
    owner_phone TEXT,
    vehicle_registration TEXT,
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_color TEXT
) AS $$
BEGIN
    -- Check if the current user is an authority user
    IF NOT EXISTS (
        SELECT 1 FROM authority_profiles 
        WHERE profile_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Only authority users can view pass owner details';
    END IF;

    -- Return pass owner and vehicle information
    RETURN QUERY
    SELECT 
        p.profile_id as owner_id,
        pr.full_name as owner_name,
        pr.email as owner_email,
        pr.phone_number as owner_phone,
        p.vehicle_registration,
        p.vehicle_make,
        p.vehicle_model,
        p.vehicle_color
    FROM purchased_passes p
    LEFT JOIN profiles pr ON pr.id = p.profile_id
    WHERE p.id = pass_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_owner_profile_for_authority(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_owner_identity_for_authority(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_owner_details(UUID) TO authenticated;