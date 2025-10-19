-- Simple CASCADE removal - this will remove the function and all dependent triggers
-- Run this single command in your Supabase SQL editor

DROP FUNCTION prevent_vehicle_edit_if_used() CASCADE;

-- Verify everything is removed
SELECT 'Check: No more triggers with prevent/edit names' as status;

SELECT trigger_name 
FROM information_schema.triggers 
WHERE event_object_table = 'vehicles'
  AND (trigger_name ILIKE '%prevent%' OR trigger_name ILIKE '%edit%');

-- If the above query returns no results, the constraint is completely removed!