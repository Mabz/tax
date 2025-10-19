-- Find all objects that depend on the trigger function
-- Run these queries to see what's using the function

-- 1. Find all triggers that use this function
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers 
WHERE action_statement LIKE '%prevent_vehicle_edit_if_used%';

-- 2. Alternative way to find triggers using this function
SELECT 
    schemaname,
    tablename,
    triggername,
    triggerdef
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE p.proname = 'prevent_vehicle_edit_if_used';

-- 3. Find the exact function definition to understand what it does
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'prevent_vehicle_edit_if_used';

-- 4. Check for any other dependencies
SELECT 
    pg_describe_object(classid, objid, objsubid) as dependent_object,
    pg_describe_object(refclassid, refobjid, refobjsubid) as referenced_object
FROM pg_depend d
JOIN pg_proc p ON d.refobjid = p.oid
WHERE p.proname = 'prevent_vehicle_edit_if_used'
  AND d.deptype = 'n';  -- normal dependency