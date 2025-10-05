-- Simple database schema check - compatible with all PostgreSQL versions

-- Check if tables exist
SELECT 'TABLE EXISTENCE CHECK:' as info;
SELECT 
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vehicles') 
         THEN 'vehicles table EXISTS' 
         ELSE 'vehicles table MISSING' END as vehicles_status,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vehicle_types') 
         THEN 'vehicle_types table EXISTS' 
         ELSE 'vehicle_types table MISSING' END as vehicle_types_status,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'purchased_passes') 
         THEN 'purchased_passes table EXISTS' 
         ELSE 'purchased_passes table MISSING' END as purchased_passes_status;

-- Check vehicles table columns
SELECT 'VEHICLES TABLE COLUMNS:' as info;
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check vehicle_types table columns  
SELECT 'VEHICLE_TYPES TABLE COLUMNS:' as info;
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'vehicle_types' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check purchased_passes table columns
SELECT 'PURCHASED_PASSES TABLE COLUMNS:' as info;
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'purchased_passes' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Sample data from vehicle_types (if table exists and has data)
SELECT 'SAMPLE VEHICLE_TYPES DATA:' as info;
SELECT * FROM vehicle_types LIMIT 3;