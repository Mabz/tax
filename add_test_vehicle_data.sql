-- Add test vehicle data to see the vehicle details section in action
-- This script adds sample vehicle information to existing records

-- 1. Update existing vehicles with sample data
UPDATE vehicles 
SET 
    registration_number = CASE 
        WHEN id LIKE '%1%' THEN 'ABC123GP'
        WHEN id LIKE '%2%' THEN 'XYZ789KZN'
        WHEN id LIKE '%3%' THEN 'DEF456WC'
        ELSE CONCAT('REG', SUBSTRING(id, 1, 3))
    END,
    vin_number = CASE 
        WHEN id LIKE '%1%' THEN '1HGBH41JXMN109186'
        WHEN id LIKE '%2%' THEN '2FMDK3GC4DBA12345'
        WHEN id LIKE '%3%' THEN '3VWFE21C04M000001'
        ELSE CONCAT('VIN', UPPER(SUBSTRING(id, 1, 14)))
    END,
    make = CASE 
        WHEN id LIKE '%1%' THEN 'Toyota'
        WHEN id LIKE '%2%' THEN 'Ford'
        WHEN id LIKE '%3%' THEN 'Volkswagen'
        ELSE 'Honda'
    END,
    model = CASE 
        WHEN id LIKE '%1%' THEN 'Corolla'
        WHEN id LIKE '%2%' THEN 'Ranger'
        WHEN id LIKE '%3%' THEN 'Polo'
        ELSE 'Civic'
    END,
    year = CASE 
        WHEN id LIKE '%1%' THEN 2020
        WHEN id LIKE '%2%' THEN 2019
        WHEN id LIKE '%3%' THEN 2021
        ELSE 2018
    END,
    color = CASE 
        WHEN id LIKE '%1%' THEN 'White'
        WHEN id LIKE '%2%' THEN 'Blue'
        WHEN id LIKE '%3%' THEN 'Silver'
        ELSE 'Black'
    END
WHERE id IS NOT NULL;

-- 2. Update purchased_passes with vehicle data from vehicles table
UPDATE purchased_passes pp
SET 
    vehicle_registration_number = v.registration_number,
    vehicle_vin = v.vin_number,
    vehicle_description = CONCAT(v.make, ' ', v.model, ' (', v.year, ')')
FROM vehicles v
WHERE pp.vehicle_id = v.id
  AND pp.vehicle_id IS NOT NULL;

-- 3. For passes without a vehicle_id, add some sample data
UPDATE purchased_passes 
SET 
    vehicle_registration_number = 'SAMPLE123GP',
    vehicle_vin = '1SAMPLE123456789',
    vehicle_description = 'Toyota Corolla (2020)'
WHERE vehicle_id IS NULL 
  AND (vehicle_registration_number IS NULL OR vehicle_registration_number = '')
  AND id IS NOT NULL;

-- 4. Show updated data
SELECT 
    'Updated passes with vehicle data' as info,
    id,
    vehicle_description,
    vehicle_registration_number,
    vehicle_vin
FROM purchased_passes 
WHERE vehicle_registration_number IS NOT NULL
LIMIT 5;

-- 5. Show vehicles data
SELECT 
    'Updated vehicles data' as info,
    id,
    description,
    registration_number,
    vin_number,
    make,
    model,
    year,
    color
FROM vehicles 
LIMIT 5;