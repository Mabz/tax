-- Populate vehicle data correctly based on actual schema
-- The schema already has all the required columns, we just need to populate them

-- 1. First, let's see what data we currently have
SELECT 
    'Current vehicles data' as info,
    COUNT(*) as total_vehicles,
    COUNT(number_plate) as has_number_plate,
    COUNT(registration_number) as has_registration_number,
    COUNT(vin) as has_vin,
    COUNT(make) as has_make,
    COUNT(model) as has_model
FROM vehicles;

SELECT 
    'Current passes data' as info,
    COUNT(*) as total_passes,
    COUNT(vehicle_id) as has_vehicle_id,
    COUNT(vehicle_number_plate) as has_vehicle_number_plate,
    COUNT(vehicle_registration_number) as has_vehicle_registration_number,
    COUNT(vehicle_vin) as has_vehicle_vin
FROM purchased_passes;

-- 2. Add sample data to vehicles if they're missing key information
UPDATE vehicles 
SET 
    registration_number = COALESCE(
        registration_number, 
        number_plate, 
        'REG' || LPAD((ROW_NUMBER() OVER (ORDER BY created_at))::text, 3, '0') || 'GP'
    ),
    vin = COALESCE(
        vin,
        '1SAMPLE' || UPPER(SUBSTRING(id::text, 1, 10))
    ),
    make = COALESCE(
        make,
        CASE (ROW_NUMBER() OVER (ORDER BY created_at)) % 4
            WHEN 1 THEN 'Toyota'
            WHEN 2 THEN 'Ford'
            WHEN 3 THEN 'Volkswagen'
            ELSE 'Honda'
        END
    ),
    model = COALESCE(
        model,
        CASE (ROW_NUMBER() OVER (ORDER BY created_at)) % 4
            WHEN 1 THEN 'Corolla'
            WHEN 2 THEN 'Ranger'
            WHEN 3 THEN 'Polo'
            ELSE 'Civic'
        END
    ),
    year = COALESCE(
        year,
        2018 + ((ROW_NUMBER() OVER (ORDER BY created_at)) % 5)
    ),
    color = COALESCE(
        color,
        CASE (ROW_NUMBER() OVER (ORDER BY created_at)) % 5
            WHEN 1 THEN 'White'
            WHEN 2 THEN 'Blue'
            WHEN 3 THEN 'Silver'
            WHEN 4 THEN 'Black'
            ELSE 'Red'
        END
    )
WHERE registration_number IS NULL 
   OR vin IS NULL 
   OR make IS NULL 
   OR model IS NULL 
   OR year IS NULL 
   OR color IS NULL;

-- 3. Update purchased_passes with vehicle data from vehicles table
UPDATE purchased_passes pp
SET 
    vehicle_registration_number = COALESCE(
        pp.vehicle_registration_number, 
        v.registration_number, 
        v.number_plate
    ),
    vehicle_vin = COALESCE(
        pp.vehicle_vin,
        v.vin
    ),
    vehicle_make = COALESCE(
        pp.vehicle_make,
        v.make
    ),
    vehicle_model = COALESCE(
        pp.vehicle_model,
        v.model
    ),
    vehicle_year = COALESCE(
        pp.vehicle_year,
        v.year
    ),
    vehicle_color = COALESCE(
        pp.vehicle_color,
        v.color
    ),
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

-- 4. For passes without a vehicle_id, add sample data for testing
UPDATE purchased_passes 
SET 
    vehicle_registration_number = COALESCE(vehicle_registration_number, 'TEST123GP'),
    vehicle_vin = COALESCE(vehicle_vin, '1TEST1234567890123'),
    vehicle_make = COALESCE(vehicle_make, 'Toyota'),
    vehicle_model = COALESCE(vehicle_model, 'Corolla'),
    vehicle_year = COALESCE(vehicle_year, 2020),
    vehicle_color = COALESCE(vehicle_color, 'White'),
    vehicle_description = COALESCE(vehicle_description, 'Toyota Corolla (2020)')
WHERE vehicle_id IS NULL;

-- 5. Show the results
SELECT 
    'Updated vehicles sample' as info,
    id,
    description,
    number_plate,
    registration_number,
    vin,
    make,
    model,
    year,
    color
FROM vehicles 
LIMIT 5;

SELECT 
    'Updated passes sample' as info,
    id,
    vehicle_description,
    vehicle_registration_number,
    vehicle_vin,
    vehicle_make,
    vehicle_model,
    vehicle_year,
    vehicle_color
FROM purchased_passes 
WHERE vehicle_registration_number IS NOT NULL
LIMIT 5;

-- 6. Final summary
SELECT 
    'Final summary' as info,
    'vehicles' as table_name,
    COUNT(*) as total_records,
    COUNT(registration_number) as with_registration,
    COUNT(vin) as with_vin,
    COUNT(make) as with_make,
    COUNT(model) as with_model
FROM vehicles

UNION ALL

SELECT 
    'Final summary' as info,
    'purchased_passes' as table_name,
    COUNT(*) as total_records,
    COUNT(vehicle_registration_number) as with_registration,
    COUNT(vehicle_vin) as with_vin,
    COUNT(vehicle_make) as with_make,
    COUNT(vehicle_model) as with_model
FROM purchased_passes;