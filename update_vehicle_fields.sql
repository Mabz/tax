-- Update vehicle fields in purchased_passes table
-- This script adds the new vehicle_registration_number column and migrates data

-- 1. Add the new column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'vehicle_registration_number'
    ) THEN
        ALTER TABLE purchased_passes 
        ADD COLUMN vehicle_registration_number TEXT;
        
        RAISE NOTICE 'Added vehicle_registration_number column to purchased_passes table';
    ELSE
        RAISE NOTICE 'vehicle_registration_number column already exists in purchased_passes table';
    END IF;
END $$;

-- 2. Migrate existing data from vehicle_number_plate to vehicle_registration_number
UPDATE purchased_passes 
SET vehicle_registration_number = vehicle_number_plate 
WHERE vehicle_number_plate IS NOT NULL 
  AND vehicle_registration_number IS NULL;

-- 3. Update passes with vehicle data from the vehicles table
UPDATE purchased_passes pp
SET 
    vehicle_registration_number = COALESCE(v.registration_number, v.number_plate),
    vehicle_vin = v.vin_number,
    vehicle_description = CASE 
        WHEN v.make IS NOT NULL AND v.model IS NOT NULL THEN 
            CONCAT(v.make, ' ', v.model, 
                   CASE WHEN v.year IS NOT NULL THEN CONCAT(' (', v.year, ')') ELSE '' END)
        ELSE 
            COALESCE(v.description, pp.vehicle_description)
    END
FROM vehicles v
WHERE pp.vehicle_id = v.id
  AND pp.vehicle_id IS NOT NULL;

-- 4. Show summary of updated records
SELECT 
    COUNT(*) as total_passes,
    COUNT(vehicle_registration_number) as passes_with_registration,
    COUNT(vehicle_vin) as passes_with_vin,
    COUNT(vehicle_description) as passes_with_description
FROM purchased_passes;

-- 5. Show sample of updated data
SELECT 
    id,
    vehicle_description,
    vehicle_registration_number,
    vehicle_vin,
    vehicle_number_plate -- old field for comparison
FROM purchased_passes 
WHERE vehicle_id IS NOT NULL 
LIMIT 5;

-- 6. Final completion message
DO $$ 
BEGIN
    RAISE NOTICE 'Vehicle field migration completed successfully';
END $$;