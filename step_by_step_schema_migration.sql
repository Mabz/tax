-- Step-by-step schema migration for vehicle data
-- This script adds columns one by one and provides feedback

-- STEP 1: Add missing columns to vehicles table
DO $$ 
BEGIN
    -- Add vin_number column to vehicles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'vin_number'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN vin_number TEXT;
        RAISE NOTICE 'SUCCESS: Added vin_number column to vehicles table';
    ELSE
        RAISE NOTICE 'INFO: vin_number column already exists in vehicles table';
    END IF;
    
    -- Add registration_number column to vehicles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'registration_number'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN registration_number TEXT;
        RAISE NOTICE 'SUCCESS: Added registration_number column to vehicles table';
    ELSE
        RAISE NOTICE 'INFO: registration_number column already exists in vehicles table';
    END IF;
    
    -- Add make column to vehicles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'make'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN make TEXT;
        RAISE NOTICE 'SUCCESS: Added make column to vehicles table';
    ELSE
        RAISE NOTICE 'INFO: make column already exists in vehicles table';
    END IF;
    
    -- Add model column to vehicles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'model'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN model TEXT;
        RAISE NOTICE 'SUCCESS: Added model column to vehicles table';
    ELSE
        RAISE NOTICE 'INFO: model column already exists in vehicles table';
    END IF;
    
    -- Add year column to vehicles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'year'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN year INTEGER;
        RAISE NOTICE 'SUCCESS: Added year column to vehicles table';
    ELSE
        RAISE NOTICE 'INFO: year column already exists in vehicles table';
    END IF;
    
    -- Add color column to vehicles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' 
        AND column_name = 'color'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE vehicles ADD COLUMN color TEXT;
        RAISE NOTICE 'SUCCESS: Added color column to vehicles table';
    ELSE
        RAISE NOTICE 'INFO: color column already exists in vehicles table';
    END IF;
END $$;

-- STEP 2: Add missing columns to purchased_passes table
DO $$ 
BEGIN
    -- Add vehicle_registration_number column to purchased_passes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'vehicle_registration_number'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN vehicle_registration_number TEXT;
        RAISE NOTICE 'SUCCESS: Added vehicle_registration_number column to purchased_passes table';
    ELSE
        RAISE NOTICE 'INFO: vehicle_registration_number column already exists in purchased_passes table';
    END IF;
    
    -- Add vehicle_vin column to purchased_passes (if it doesn't exist)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'vehicle_vin'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN vehicle_vin TEXT;
        RAISE NOTICE 'SUCCESS: Added vehicle_vin column to purchased_passes table';
    ELSE
        RAISE NOTICE 'INFO: vehicle_vin column already exists in purchased_passes table';
    END IF;
END $$;

-- STEP 3: Populate vehicles table with sample data
DO $$
BEGIN
    -- Only add sample data if the table is empty or has vehicles without registration numbers
    IF (SELECT COUNT(*) FROM vehicles WHERE registration_number IS NOT NULL) = 0 THEN
        -- Update existing vehicles with sample data
        UPDATE vehicles 
        SET 
            registration_number = CASE 
                WHEN number_plate IS NOT NULL THEN number_plate
                ELSE 'REG' || LPAD((ROW_NUMBER() OVER())::text, 3, '0') || 'GP'
            END,
            vin_number = '1SAMPLE' || UPPER(SUBSTRING(id::text, 1, 10)),
            make = CASE (ROW_NUMBER() OVER()) % 4
                WHEN 1 THEN 'Toyota'
                WHEN 2 THEN 'Ford'
                WHEN 3 THEN 'Volkswagen'
                ELSE 'Honda'
            END,
            model = CASE (ROW_NUMBER() OVER()) % 4
                WHEN 1 THEN 'Corolla'
                WHEN 2 THEN 'Ranger'
                WHEN 3 THEN 'Polo'
                ELSE 'Civic'
            END,
            year = 2018 + ((ROW_NUMBER() OVER()) % 5),
            color = CASE (ROW_NUMBER() OVER()) % 5
                WHEN 1 THEN 'White'
                WHEN 2 THEN 'Blue'
                WHEN 3 THEN 'Silver'
                WHEN 4 THEN 'Black'
                ELSE 'Red'
            END
        WHERE registration_number IS NULL OR vin_number IS NULL;
        
        RAISE NOTICE 'SUCCESS: Updated existing vehicles with sample data';
    ELSE
        RAISE NOTICE 'INFO: Vehicles already have registration data, skipping sample data insertion';
    END IF;
END $$;

-- STEP 4: Update purchased_passes with vehicle data
DO $$
BEGIN
    -- Update passes that have a vehicle_id
    UPDATE purchased_passes pp
    SET 
        vehicle_registration_number = COALESCE(pp.vehicle_registration_number, v.registration_number, v.number_plate),
        vehicle_vin = COALESCE(pp.vehicle_vin, v.vin_number),
        vehicle_description = COALESCE(
            pp.vehicle_description,
            CASE 
                WHEN v.make IS NOT NULL AND v.model IS NOT NULL THEN
                    v.make || ' ' || v.model || 
                    CASE WHEN v.year IS NOT NULL THEN ' (' || v.year || ')' ELSE '' END
                ELSE v.description
            END
        )
    FROM vehicles v
    WHERE pp.vehicle_id = v.id;
    
    -- Update passes without vehicle_id with sample data
    UPDATE purchased_passes 
    SET 
        vehicle_registration_number = COALESCE(vehicle_registration_number, 'SAMPLE123GP'),
        vehicle_vin = COALESCE(vehicle_vin, '1SAMPLE1234567890'),
        vehicle_description = COALESCE(vehicle_description, 'Sample Vehicle (2020)')
    WHERE vehicle_registration_number IS NULL OR vehicle_vin IS NULL;
    
    RAISE NOTICE 'SUCCESS: Updated purchased_passes with vehicle data';
END $$;

-- STEP 5: Verification
SELECT 
    'FINAL VERIFICATION' as step,
    'vehicles' as table_name,
    COUNT(*) as total_records,
    COUNT(registration_number) as with_registration,
    COUNT(vin_number) as with_vin,
    COUNT(make) as with_make,
    COUNT(model) as with_model
FROM vehicles

UNION ALL

SELECT 
    'FINAL VERIFICATION' as step,
    'purchased_passes' as table_name,
    COUNT(*) as total_records,
    COUNT(vehicle_registration_number) as with_registration,
    COUNT(vehicle_vin) as with_vin,
    0 as with_make,
    0 as with_model
FROM purchased_passes;

-- Show sample of final data
SELECT 
    'SAMPLE FINAL DATA' as step,
    pp.id as pass_id,
    pp.vehicle_description,
    pp.vehicle_registration_number,
    pp.vehicle_vin
FROM purchased_passes pp
WHERE pp.vehicle_registration_number IS NOT NULL
LIMIT 5;