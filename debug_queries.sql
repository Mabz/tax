-- Debug queries to find the source of the purchase pass constraint
-- Run these in your Supabase SQL editor

-- 1. Check for triggers on the vehicles table
SELECT 
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'vehicles';

-- 2. Check for check constraints on the vehicles table
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints cc
JOIN information_schema.table_constraints tc ON cc.constraint_name = tc.constraint_name
WHERE tc.table_name = 'vehicles';

-- 3. Check for RLS policies on the vehicles table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'vehicles';

-- 4. Look for any functions that might contain the purchase pass constraint
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_definition ILIKE '%purchased%pass%' 
   OR routine_definition ILIKE '%cannot%edit%'
   OR routine_definition ILIKE '%P0001%';

-- 5. Check the vehicles table structure for any constraints
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vehicles'
ORDER BY ordinal_position;