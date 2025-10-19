-- Remove the specific trigger and its function
-- Run these commands in order in your Supabase SQL editor

-- Step 1: Drop the trigger from the vehicles table
DROP TRIGGER IF EXISTS prevent_vehicle_edit_if_used ON vehicles;

-- Step 2: Now drop the trigger function (since no trigger uses it anymore)
DROP FUNCTION IF EXISTS prevent_vehicle_edit_if_used();

-- Step 3: Verify the trigger is gone
SELECT trigger_name 
FROM information_schema.triggers 
WHERE event_object_table = 'vehicles';

-- Step 4: Verify the function is gone
SELECT routine_name
FROM information_schema.routines 
WHERE routine_name = 'prevent_vehicle_edit_if_used';

-- If the above queries return no results, the trigger and function are successfully removed!