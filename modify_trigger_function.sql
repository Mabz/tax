-- Modify the trigger function to allow vehicle updates with purchased passes
-- This replaces the blocking logic with allowing logic

-- First, let's find the exact function name
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_definition ILIKE '%purchased%pass%' 
   AND routine_definition ILIKE '%cannot%edit%';

-- The function is likely named something like:
-- prevent_vehicle_update_with_passes()
-- check_vehicle_purchased_passes()
-- vehicle_update_constraint()

-- Replace the function with this modified version:
-- (Replace 'function_name' with the actual function name from the query above)

CREATE OR REPLACE FUNCTION prevent_vehicle_update_with_passes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- MODIFIED: Allow vehicle updates even with purchased passes
    -- Original constraint removed to allow users to edit their vehicles
    
    -- Optional: Log the update for audit purposes
    RAISE NOTICE 'Vehicle % updated by user. Purchased passes will be updated automatically.', OLD.id;
    
    -- Always allow the update to proceed
    RETURN NEW;
END;
$$;

-- Alternative approach - if you want to keep some validation but allow updates:
CREATE OR REPLACE FUNCTION prevent_vehicle_update_with_passes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if there are purchased passes for this vehicle
    IF EXISTS (
        SELECT 1 
        FROM purchased_passes 
        WHERE vehicle_id = OLD.id
    ) THEN
        -- Log that we're updating a vehicle with passes (for audit)
        RAISE NOTICE 'Updating vehicle % that has purchased passes. Related passes will be updated automatically.', OLD.id;
        
        -- Update the related purchased passes with new vehicle information
        UPDATE purchased_passes 
        SET 
            vehicle_make = NEW.make,
            vehicle_model = NEW.model,
            vehicle_year = NEW.year,
            vehicle_color = NEW.color,
            vehicle_vin = NEW.vin,
            vehicle_registration_number = NEW.registration_number,
            vehicle_description = CASE 
                WHEN NEW.make IS NOT NULL AND NEW.model IS NOT NULL AND NEW.year IS NOT NULL THEN
                    NEW.make || ' ' || NEW.model || ' (' || NEW.year || ')'
                WHEN NEW.make IS NOT NULL AND NEW.model IS NOT NULL THEN
                    NEW.make || ' ' || NEW.model
                ELSE
                    COALESCE(NEW.make, '') || COALESCE(' ' || NEW.model, '')
            END
        WHERE vehicle_id = OLD.id;
    END IF;
    
    -- Always allow the update to proceed
    RETURN NEW;
END;
$$;