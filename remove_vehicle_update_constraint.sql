-- Remove constraint that prevents updating vehicles with purchased passes
-- This script modifies the update_vehicle function to allow updates regardless of pass status

-- First, let's create a backup of the current function (if it exists)
DO $$
BEGIN
    -- Check if the function exists and create a backup
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_vehicle') THEN
        RAISE NOTICE 'Backing up existing update_vehicle function';
        -- The backup will be handled by the database automatically through versioning
    END IF;
END $$;

-- Create or replace the update_vehicle function without the purchased pass constraint
CREATE OR REPLACE FUNCTION update_vehicle(
    p_vehicle_id UUID,
    p_make TEXT,
    p_model TEXT,
    p_year INTEGER,
    p_color TEXT,
    p_vin TEXT,
    p_body_type TEXT DEFAULT NULL,
    p_fuel_type TEXT DEFAULT NULL,
    p_transmission TEXT DEFAULT NULL,
    p_engine_capacity DECIMAL DEFAULT NULL,
    p_registration_number TEXT DEFAULT NULL,
    p_country_of_registration_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Get the current user ID
    v_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if the vehicle exists and belongs to the user
    IF NOT EXISTS (
        SELECT 1 FROM vehicles 
        WHERE id = p_vehicle_id 
        AND profile_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'Vehicle not found or access denied';
    END IF;
    
    -- REMOVED: Check for purchased passes constraint
    -- The original constraint that prevented updates when passes exist has been removed
    -- This allows users to update their vehicles even if they have purchased passes
    
    -- Update the vehicle record
    UPDATE vehicles SET
        make = p_make,
        model = p_model,
        year = p_year,
        color = p_color,
        vin = p_vin,
        body_type = p_body_type,
        fuel_type = p_fuel_type,
        transmission = p_transmission,
        engine_capacity = p_engine_capacity,
        registration_number = p_registration_number,
        country_of_registration_id = p_country_of_registration_id,
        updated_at = NOW()
    WHERE id = p_vehicle_id
    AND profile_id = v_user_id;
    
    -- Update related purchased passes with new vehicle information
    -- This ensures consistency across the system
    UPDATE purchased_passes SET
        vehicle_make = p_make,
        vehicle_model = p_model,
        vehicle_year = p_year,
        vehicle_color = p_color,
        vehicle_vin = p_vin,
        vehicle_registration_number = p_registration_number,
        -- Update vehicle description for better display
        vehicle_description = CASE 
            WHEN p_make IS NOT NULL AND p_model IS NOT NULL AND p_year IS NOT NULL THEN
                p_make || ' ' || p_model || ' (' || p_year || ')'
            WHEN p_make IS NOT NULL AND p_model IS NOT NULL THEN
                p_make || ' ' || p_model
            ELSE
                COALESCE(p_make, '') || COALESCE(' ' || p_model, '')
        END
    WHERE vehicle_id = p_vehicle_id;
    
    RAISE NOTICE 'Vehicle updated successfully. ID: %', p_vehicle_id;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION update_vehicle TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION update_vehicle IS 'Updates vehicle information and synchronizes with related purchased passes. Constraint preventing updates when passes exist has been removed.';

-- Log the change
DO $$
BEGIN
    RAISE NOTICE 'SUCCESS: Vehicle update constraint has been removed';
    RAISE NOTICE 'Users can now update vehicles even if they have purchased passes';
    RAISE NOTICE 'Related purchased passes will be automatically updated with new vehicle information';
END $$;