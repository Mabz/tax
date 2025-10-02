-- Complete diagnostic to understand the issue
-- Run this to see exactly what's in your database

-- 1. Check pass_templates table structure
SELECT 'PASS_TEMPLATES COLUMNS:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_templates'
ORDER BY ordinal_position;

-- 2. Check if the function exists and its signature
SELECT 'FUNCTION SIGNATURES:' as info;
SELECT 
    routine_name,
    routine_type,
    specific_name,
    data_type,
    type_udt_name
FROM information_schema.routines 
WHERE routine_name = 'create_pass_template';

-- 3. Check function parameters
SELECT 'FUNCTION PARAMETERS:' as info;
SELECT 
    r.routine_name,
    p.parameter_name,
    p.data_type,
    p.parameter_mode,
    p.ordinal_position
FROM information_schema.routines r
JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE r.routine_name = 'create_pass_template'
ORDER BY p.ordinal_position;

-- 4. Try to call the function with test data to see the exact error
SELECT 'TESTING FUNCTION CALL:' as info;
DO $$
BEGIN
    BEGIN
        PERFORM create_pass_template(
            '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615'::UUID,  -- target_authority_id
            'f029133e-39cf-4ac4-a04e-25f7b59ef604'::UUID,  -- creator_profile_id (from your error log)
            '02d4b3f7-b784-4c40-8078-4f0ad36d1590'::UUID,  -- vehicle_type_id
            'Test Bus Pass',                                -- description
            1,                                              -- entry_limit
            30,                                             -- expiration_days
            30,                                             -- pass_advance_days
            0.00,                                           -- tax_amount
            'GBP',                                          -- currency_code
            NULL,                                           -- target_entry_point_id
            NULL,                                           -- target_exit_point_id
            FALSE                                           -- allow_user_selectable_points
        );
        RAISE NOTICE 'Function call succeeded!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Function call failed with error: %', SQLERRM;
    END;
END;
$$;

-- 5. Check if there are any other tables or views with similar names
SELECT 'RELATED OBJECTS:' as info;
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name LIKE '%pass%template%' OR table_name LIKE '%template%';

-- 6. Check authorities table to make sure the authority exists
SELECT 'AUTHORITY CHECK:' as info;
SELECT 
    id,
    name,
    country_id
FROM authorities 
WHERE id = '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615';

-- 7. Check if RLS is enabled and might be causing issues
SELECT 'RLS STATUS:' as info;
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'pass_templates';