-- Debug the create_pass_template function
-- Check if the function exists and what its definition looks like

-- 1. Check if the function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'create_pass_template';

-- 2. Check the pass_templates table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'pass_templates'
ORDER BY ordinal_position;

-- 3. Try to see the actual function source
SELECT 
    proname as function_name,
    prosrc as source_code
FROM pg_proc 
WHERE proname = 'create_pass_template';

-- 4. Check if there are any views or other objects that might be interfering
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name LIKE '%pass_template%';