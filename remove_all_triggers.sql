-- Remove ALL triggers that depend on the function
-- Based on the error, we need to remove both triggers

-- Step 1: Drop the first trigger
DROP TRIGGER IF EXISTS prevent_vehicle_edit_if_used ON vehicles;

-- Step 2: Drop the second trigger (from the error message)
DROP TRIGGER IF EXISTS trg_prevent_vehicle_update_if_used ON vehicles;

-- Step 3: Now drop the function (should work since no triggers depend on it)
DROP FUNCTION IF EXISTS prevent_vehicle_edit_if_used();

-- Step 4: Verify everything is gone
SELECT 'Remaining triggers:' as check_type, trigger_name as name
FROM information_schema.triggers 
WHERE event_object_table = 'vehicles'
  AND (trigger_name LIKE '%prevent%' OR trigger_name LIKE '%vehicle%edit%')

UNION ALL

SELECT 'Remaining functions:' as check_type, routine_name as name
FROM information_schema.routines 
WHERE routine_name = 'prevent_vehicle_edit_if_used';

-- Alternative: Use CASCADE to drop everything at once (be careful!)
-- DROP FUNCTION prevent_vehicle_edit_if_used() CASCADE;