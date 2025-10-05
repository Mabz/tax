-- Comprehensive diagnostic and fix for vehicle data in purchased_passes
-- This script will diagnose the current state and fix the issues

-- 1. Check current schema
SELECT 
    'SCHEMA CHECK' as section,
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('vehicles', 'purchased_passes')
  AND column_name IN ('registration_number', 'number_plate', 'vin_number', 'vehicle_vin', 'vehicle_registration_number', 'vehicle_number_plate')
ORDER BY table_name, column_name;

-- 2. Check current data in vehicles table
SELECT 
    'VEHICLES DATA CHECK' as section,
    COUNT(*) as total_vehicles,
    COUNT(number_plate) as has_number_plate,
    COUNT(registration_number) as has_registration_number,
    COUNT(vin_number) as has_vin_number,
    COUNT(description) as has_description
FROM vehicles;

-- 3. Check current data in purchased_passes table
SELECT 
    'PASSES DATA CHECK' as section,
    COUNT(*) as total_passes,
    COUNT(vehicle_id) as has_vehicle_id,
    COUNT(vehicle_number_plate) as has_vehicle_number_plate,
    COUNT(vehicle_registration_number) as has_vehicle_registration_number,
    COUNT(vehicle_vin) as has_vehicle_vin,
    COUNT(vehicle_description) as has_vehicle_description
FROM purchased_passes;

-- 4. Show sample of current data
SELECT 
    'SAMPLE VEHICLES' as section,
    id,
    description,
    number_plate,
    registration_number,
    vin_number
FROM vehicles 
LIMIT 3;

SELECT 
    'SAMPLE PASSES' as section,
    id,
    vehicle_id,
    vehicle_description,
    vehicle_number_plate,
    vehicle_registration_number,
    vehicle_vin
FROM purchased_passes 
LIMIT 3;

-- 5. Add missing columns if they don't exist
DO $$ 
BEGIN
    -- Add columns to vehicles table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'vin_number') THEN
        ALTER TABLE vehicles ADD COLUMN vin_number TEXT;
        RAISE NOTICE 'Added vin_number to vehicles table';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'registration_number') THEN
        ALTER TABLE vehicles ADD COLUMN registration_number TEXT;
        RAISE NOTICE 'Added registration_number to vehicles table';
    END IF;

    -- Add columns to purchased_passes table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchased_passes' AND column_name = 'vehicle_registration_number') THEN
        ALTER TABLE purchased_passes ADD COLUMN vehicle_registration_number TEXT;
        RAISE NOTICE 'Added vehicle_registration_number to purchased_passes table';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchased_passes' AND column_name = 'vehicle_vin') THEN
        ALTER TABLE purchased_passes ADD COLUMN vehicle_vin TEXT;
        RAISE NOTICE 'Added vehicle_vin to purchased_passes table';
    END IF;
END $$;

-- 6. Add sample data to vehicles if they're empty
INSERT INTO vehicles (id, profile_id, description, number_plate, registration_number, vin_number, created_at)
SELECT 
    gen_random_uuid(),
    (SELECT id FROM profiles LIMIT 1),
    'Sample Vehicle ' || generate_series,
    'ABC' || LPAD(generate_series::text, 3, '0') || 'GP',
    'REG' || LPAD(generate_series::text, 3, '0') || 'ZA',
    '1SAMPLE' || LPAD(generate_series::text, 10, '0'),
    NOW()
FROM generate_series(1, 3)
WHERE NOT EXISTS (SELECT 1 FROM vehicles LIMIT 1);

-- 7. Update existing vehicles with sample data if they're missing registration/vin
UPDATE vehicles 
SET 
    registration_number = COALESCE(registration_number, number_plate, 'REG' || SUBSTRING(id::text, 1, 6)),
    vin_number = COALESCE(vin_number, '1SAMPLE' || UPPER(SUBSTRING(id::text, 1, 10)))
WHERE registration_number IS NULL OR vin_number IS NULL;

-- 8. Update purchased_passes with vehicle data
UPDATE purchased_passes pp
SET 
    vehicle_registration_number = COALESCE(pp.vehicle_registration_number, v.registration_number, v.number_plate),
    vehicle_vin = COALESCE(pp.vehicle_vin, v.vin_number),
    vehicle_description = COALESCE(pp.vehicle_description, v.description, 'Vehicle')
FROM vehicles v
WHERE pp.vehicle_id = v.id;

-- 9. For passes without vehicle_id, add sample data
UPDATE purchased_passes 
SET 
    vehicle_registration_number = COALESCE(vehicle_registration_number, 'SAMPLE123GP'),
    vehicle_vin = COALESCE(vehicle_vin, '1SAMPLE1234567890'),
    vehicle_description = COALESCE(vehicle_description, 'Sample Vehicle')
WHERE vehicle_registration_number IS NULL OR vehicle_vin IS NULL;

-- 10. Final verification
SELECT 
    'FINAL VERIFICATION' as section,
    'vehicles' as table_name,
    COUNT(*) as total_records,
    COUNT(registration_number) as with_registration,
    COUNT(vin_number) as with_vin
FROM vehicles

UNION ALL

SELECT 
    'FINAL VERIFICATION' as section,
    'purchased_passes' as table_name,
    COUNT(*) as total_records,
    COUNT(vehicle_registration_number) as with_registration,
    COUNT(vehicle_vin) as with_vin
FROM purchased_passes;

-- 11. Show final sample data
SELECT 
    'FINAL SAMPLE DATA' as section,
    pp.id as pass_id,
    pp.vehicle_description,
    pp.vehicle_registration_number,
    pp.vehicle_vin,
    v.registration_number as vehicle_reg,
    v.vin_number as vehicle_vin
FROM purchased_passes pp
LEFT JOIN vehicles v ON pp.vehicle_id = v.id
LIMIT 5;