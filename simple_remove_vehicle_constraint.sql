-- Simple approach to remove vehicle update constraint
-- This script handles various possible function structures

DO $$
DECLARE
    func_exists BOOLEAN;
BEGIN
    -- Check if update_vehicle function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'update_vehicle'
    ) INTO func_exists;
    
    IF func_exists THEN
        RAISE NOTICE 'Found update_vehicle function, attempting to modify it';
        
        -- Drop the existing function (this will remove any constraints)
        DROP FUNCTION IF EXISTS update_vehicle CASCADE;
        RAISE NOTICE 'Dropped existing update_vehicle function';
        
        -- Create a new version without constraints
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
        AS $func$
        DECLARE
            v_user_id UUID;
        BEGIN
            -- Get the current user ID
            v_user_id := auth.uid();
            
            -- Check if user is authenticated
            IF v_user_id IS NULL THEN
                RAISE EXCEPTION 'User not authenticated';
            END IF;
            
            -- Update the vehicle directly without any pass-related constraints
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
            
            -- Check if the update affected any rows
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Vehicle not found or access denied';
            END IF;
            
            RAISE NOTICE 'Vehicle updated successfully without constraints';
        END;
        $func$;
        
        -- Grant permissions
        GRANT EXECUTE ON FUNCTION update_vehicle TO authenticated;
        
        RAISE NOTICE 'SUCCESS: Created new update_vehicle function without purchased pass constraints';
        
    ELSE
        RAISE NOTICE 'No update_vehicle function found - constraint may be elsewhere or not implemented yet';
        RAISE NOTICE 'The Flutter app changes should be sufficient to allow vehicle updates';
    END IF;
END $$;