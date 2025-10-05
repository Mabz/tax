-- Safe schema check that won't fail on missing columns
-- This script checks what columns actually exist before trying to query them

-- 1. Check what columns exist in vehicles table
SELECT 
    'VEHICLES TABLE COLUMNS' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vehicles'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check what columns exist in purchased_passes table
SELECT 
    'PURCHASED_PASSES TABLE COLUMNS' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'purchased_passes'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check if specific columns exist before querying them
DO $$ 
DECLARE
    vehicles_has_vin_number boolean := false;
    vehicles_has_registration_number boolean := false;
    passes_has_vehicle_registration_number boolean := false;
    passes_has_vehicle_vin boolean := false;
BEGIN
    -- Check vehicles table columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' AND column_name = 'vin_number'
    ) INTO vehicles_has_vin_number;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vehicles' AND column_name = 'registration_number'
    ) INTO vehicles_has_registration_number;
    
    -- Check purchased_passes table columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'vehicle_registration_number'
    ) INTO passes_has_vehicle_registration_number;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'vehicle_vin'
    ) INTO passes_has_vehicle_vin;
    
    -- Report findings
    RAISE NOTICE 'COLUMN EXISTENCE CHECK:';
    RAISE NOTICE 'vehicles.vin_number: %', vehicles_has_vin_number;
    RAISE NOTICE 'vehicles.registration_number: %', vehicles_has_registration_number;
    RAISE NOTICE 'purchased_passes.vehicle_registration_number: %', passes_has_vehicle_registration_number;
    RAISE NOTICE 'purchased_passes.vehicle_vin: %', passes_has_vehicle_vin;
END $$;

-- 4. Show sample data from vehicles table (only existing columns)
SELECT 
    'SAMPLE VEHICLES DATA' as section,
    id,
    profile_id,
    description,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'number_plate')
         THEN number_plate ELSE 'N/A' END as number_plate_status,
    created_at
FROM vehicles 
LIMIT 3;

-- 5. Show sample data from purchased_passes table (only existing columns)
SELECT 
    'SAMPLE PASSES DATA' as section,
    id,
    vehicle_id,
    vehicle_description,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchased_passes' AND column_name = 'vehicle_number_plate')
         THEN vehicle_number_plate ELSE 'N/A' END as vehicle_number_plate_status,
    created_at
FROM purchased_passes 
LIMIT 3;