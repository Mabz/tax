-- Check current database schema to understand what exists
-- Run this first to see what tables and columns are available

-- Check what tables exist
SELECT 
    'EXISTING TABLES' as section,
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public'
AND table_name IN (
    'profiles', 'purchased_passes', 'borders', 'authorities', 
    'border_official_borders', 'pass_movements'
)
ORDER BY table_name;

-- Check purchased_passes table structure
SELECT 
    'PURCHASED_PASSES COLUMNS' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'purchased_passes' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if profiles table exists and its structure
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'profiles' 
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE 'PROFILES TABLE EXISTS';
    ELSE
        RAISE NOTICE 'PROFILES TABLE DOES NOT EXIST';
    END IF;
END $$;

-- Check profiles table columns if it exists
SELECT 
    'PROFILES COLUMNS' as section,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check borders table structure
SELECT 
    'BORDERS COLUMNS' as section,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'borders' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check what functions already exist
SELECT 
    'EXISTING FUNCTIONS' as section,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name LIKE '%pass%' OR routine_name LIKE '%border%' OR routine_name LIKE '%movement%'
ORDER BY routine_name;

-- Show sample data from key tables
SELECT 'SAMPLE PURCHASED_PASSES' as section, id, profile_id, created_at 
FROM purchased_passes 
LIMIT 3;

-- Check if auth.uid() function works
SELECT 'AUTH CHECK' as section, auth.uid() as current_user_id;