-- Remove the trigger that prevents vehicle updates when purchased passes exist
-- Run this in your Supabase SQL editor

-- First, find the exact trigger name (it might be something like 'prevent_vehicle_update_with_passes')
-- You can see the trigger name from the first debug query result

-- Then drop the trigger (replace 'trigger_name' with the actual name)
-- Common trigger names might be:
-- DROP TRIGGER IF EXISTS prevent_vehicle_update_with_passes ON vehicles;
-- DROP TRIGGER IF EXISTS check_purchased_passes_before_update ON vehicles;
-- DROP TRIGGER IF EXISTS vehicle_update_constraint ON vehicles;

-- Generic command (replace with actual trigger name):
-- DROP TRIGGER IF EXISTS [trigger_name] ON vehicles;

-- If you're not sure of the exact name, you can also drop the trigger function:
-- DROP FUNCTION IF EXISTS prevent_vehicle_update_with_passes();

-- To be safe, let's see all triggers on the vehicles table first:
SELECT trigger_name 
FROM information_schema.triggers 
WHERE event_object_table = 'vehicles';

-- Once you know the trigger name, use:
-- DROP TRIGGER IF EXISTS [exact_trigger_name] ON vehicles;