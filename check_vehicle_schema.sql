-- Comprehensive database schema check
-- Compatible with PostgreSQL 9.x and later

-- Check PostgreSQL version
SELECT 'POSTGRESQL VERSION:' as info;
SELECT version();

-- 1. Check vehicles table columns
SELECT 'VEHICLES TABLE COLUMNS:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check vehicle_types table columns  
SELECT 'VEHICLE_TYPES TABLE COLUMNS:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'vehicle_types' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check purchased_passes table columns
SELECT 'PURCHASED_PASSES TABLE COLUMNS:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'purchased_passes' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check RLS policies on purchased_passes (if supported)
SELECT 'RLS POLICIES ON PURCHASED_PASSES:' as info;
-- Note: This may fail on older PostgreSQL versions - that's expected
SELECT COALESCE(
  (SELECT COUNT(*)::text FROM pg_policies WHERE tablename = 'purchased_passes'),
  'pg_policies view not available'
) as policy_info;

-- 5. Check if RLS is enabled
SELECT 'RLS STATUS:' as info;
SELECT schemaname, tablename, rowsecurity
FROM pg_tables 
WHERE tablename = 'purchased_passes';

-- 6. Check vehicle-related RPC functions
SELECT 'VEHICLE RPC FUNCTIONS:' as info;
SELECT routine_name, routine_definition
FROM information_schema.routines 
WHERE routine_name LIKE '%vehicle%' 
  AND routine_schema = 'public'
  AND routine_type = 'FUNCTION';

-- 7. Sample data from vehicle_types to see actual column names
SELECT 'SAMPLE VEHICLE_TYPES DATA:' as info;
SELECT * FROM vehicle_types LIMIT 3;