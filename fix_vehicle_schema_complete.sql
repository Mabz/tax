-- Complete vehicle schema fix
-- This script ensures all required columns exist in both vehicles and purchased_passes tables

-- 1. Fix vehicles table schema
DO $$ 
BEGIN
    -- Add vin_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'vin_number'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN vin_number TEXT;
        RAISE NOTICE 'Added vin_number column to vehicles table';
    ELSE
        RAISE NOTICE 'vin_number column already exists in vehicles table';
    END IF;

    -- Add registration_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'registration_number'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN registration_number TEXT;
        RAISE NOTICE 'Added registration_number column to vehicles table';
    ELSE
        RAISE NOTICE 'registration_number column already exists in vehicles table';
    END IF;

    -- Add make column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'make'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN make TEXT;
        RAISE NOTICE 'Added make column to vehicles table';
    ELSE
        RAISE NOTICE 'make column already exists in vehicles table';
    END IF;

    -- Add model column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'model'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN model TEXT;
        RAISE NOTICE 'Added model column to vehicles table';
    ELSE
        RAISE NOTICE 'model column already exists in vehicles table';
    END IF;

    -- Add year column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'year'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN year INTEGER;
        RAISE NOTICE 'Added year column to vehicles table';
    ELSE
        RAISE NOTICE 'year column already exists in vehicles table';
    END IF;

    -- Add color column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'color'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN color TEXT;
        RAISE NOTICE 'Added color column to vehicles table';
    ELSE
        RAISE NOTICE 'color column already exists in vehicles table';
    END IF;
END $$;

-- 2. Fix purchased_passes table schema
DO $$ 
BEGIN
    -- Add vehicle_registration_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'vehicle_registration_number'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN vehicle_registration_number TEXT;
        RAISE NOTICE 'Added vehicle_registration_number column to purchased_passes table';
    ELSE
        RAISE NOTICE 'vehicle_registration_number column already exists in purchased_passes table';
    END IF;

    -- Ensure vehicle_vin column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'vehicle_vin'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN vehicle_vin TEXT;
        RAISE NOTICE 'Added vehicle_vin column to purchased_passes table';
    ELSE
        RAISE NOTICE 'vehicle_vin column already exists in purchased_passes table';
    END IF;
END $$;

-- 3. Migrate existing data in vehicles table
-- Copy number_plate to registration_number if registration_number is empty
UPDATE vehicles 
SET registration_number = number_plate 
WHERE number_plate IS NOT NULL 
  AND (registration_number IS NULL OR registration_number = '');

-- 4. Migrate existing data in purchased_passes table
-- Copy vehicle_number_plate to vehicle_registration_number if needed
UPDATE purchased_passes 
SET vehicle_registration_number = vehicle_number_plate 
WHERE vehicle_number_plate IS NOT NULL 
  AND (vehicle_registration_number IS NULL OR vehicle_registration_number = '');

-- 5. Update passes with vehicle data from the vehicles table
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

-- 6. Show summary of current data
SELECT 
    'vehicles' as table_name,
    COUNT(*) as total_records,
    COUNT(registration_number) as with_registration,
    COUNT(number_plate) as with_number_plate,
    COUNT(vin_number) as with_vin,
    COUNT(make) as with_make,
    COUNT(model) as with_model
FROM vehicles

UNION ALL

SELECT 
    'purchased_passes' as table_name,
    COUNT(*) as total_records,
    COUNT(vehicle_registration_number) as with_registration,
    COUNT(vehicle_number_plate) as with_number_plate,
    COUNT(vehicle_vin) as with_vin,
    COUNT(vehicle_description) as with_make,
    0 as with_model
FROM purchased_passes;

-- 7. Show sample of updated data
SELECT 
    'Sample vehicles data' as info,
    id,
    description,
    registration_number,
    number_plate,
    vin_number,
    make,
    model,
    year,
    color
FROM vehicles 
LIMIT 3;

SELECT 
    'Sample passes data' as info,
    id,
    vehicle_description,
    vehicle_registration_number,
    vehicle_number_plate,
    vehicle_vin
FROM purchased_passes 
WHERE vehicle_id IS NOT NULL 
LIMIT 3;

-- 8. Final completion message
DO $$ 
BEGIN
    RAISE NOTICE 'Complete vehicle schema migration completed successfully';
    RAISE NOTICE 'Both vehicles and purchased_passes tables have been updated';
    RAISE NOTICE 'Data has been migrated from old columns to new columns';
END $$;