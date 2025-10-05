-- Simple script to update existing passes with vehicle data
-- Run this after the schema has been fixed

-- 1. First, let's see what we're working with
SELECT 
    'Current state of passes' as info,
    COUNT(*) as total_passes,
    COUNT(vehicle_id) as passes_with_vehicle_id,
    COUNT(vehicle_registration_number) as passes_with_reg_number,
    COUNT(vehicle_vin) as passes_with_vin
FROM purchased_passes;

-- 2. Update passes that have a vehicle_id but missing vehicle details
UPDATE purchased_passes pp
SET 
    vehicle_registration_number = COALESCE(
        pp.vehicle_registration_number, 
        v.registration_number, 
        v.number_plate,
        'REG' || SUBSTRING(v.id::text, 1, 6)
    ),
    vehicle_vin = COALESCE(
        pp.vehicle_vin,
        v.vin_number,
        '1VIN' || UPPER(SUBSTRING(v.id::text, 1, 13))
    ),
    vehicle_description = COALESCE(
        pp.vehicle_description,
        CASE 
            WHEN v.make IS NOT NULL AND v.model IS NOT NULL THEN
                v.make || ' ' || v.model || 
                CASE WHEN v.year IS NOT NULL THEN ' (' || v.year || ')' ELSE '' END
            ELSE v.description
        END,
        'Vehicle'
    )
FROM vehicles v
WHERE pp.vehicle_id = v.id
  AND pp.vehicle_id IS NOT NULL;

-- 3. For passes without a vehicle_id, add some generic vehicle data for testing
UPDATE purchased_passes 
SET 
    vehicle_registration_number = COALESCE(vehicle_registration_number, 'TEST123GP'),
    vehicle_vin = COALESCE(vehicle_vin, '1TEST1234567890123'),
    vehicle_description = COALESCE(vehicle_description, 'Test Vehicle (2020)')
WHERE (vehicle_registration_number IS NULL OR vehicle_registration_number = '')
  AND (vehicle_vin IS NULL OR vehicle_vin = '');

-- 4. Show the results
SELECT 
    'Updated passes' as info,
    id,
    vehicle_description,
    vehicle_registration_number,
    vehicle_vin,
    vehicle_id
FROM purchased_passes 
WHERE vehicle_registration_number IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- 5. Summary after update
SELECT 
    'Final state of passes' as info,
    COUNT(*) as total_passes,
    COUNT(vehicle_id) as passes_with_vehicle_id,
    COUNT(vehicle_registration_number) as passes_with_reg_number,
    COUNT(vehicle_vin) as passes_with_vin
FROM purchased_passes;