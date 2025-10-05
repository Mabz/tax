-- Simple test for the pass processing fix
-- Run this after running simple_pass_processing_fix.sql

-- Check if the audit table was created correctly
SELECT 
    'Audit table columns:' as info,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'pass_processing_audit' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Show available test data
SELECT 
    'Available passes:' as info,
    id,
    pass_description,
    current_status,
    entries_remaining
FROM purchased_passes 
WHERE status = 'active' 
AND expires_at > NOW()
AND entries_remaining > 0
LIMIT 3;

-- Test the function
SELECT test_pass_processing_simple() as test_result;