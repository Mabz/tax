-- Simple check to identify the exact issue

-- 1. Check pass_templates table columns
\echo 'CHECKING PASS_TEMPLATES COLUMNS:'
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'pass_templates'
ORDER BY ordinal_position;

-- 2. Check if create_pass_template function exists
\echo 'CHECKING FUNCTION:'
SELECT routine_name, routine_type
FROM information_schema.routines 
WHERE routine_name = 'create_pass_template';

-- 3. Try a direct insert to see if the table works
\echo 'TESTING DIRECT INSERT:'
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
BEGIN
    -- Try to insert directly into pass_templates
    INSERT INTO pass_templates (
        id,
        authority_id,
        country_id,
        vehicle_type_id,
        description,
        entry_limit,
        expiration_days,
        pass_advance_days,
        tax_amount,
        currency_code,
        created_by_profile_id,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        test_id,
        '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615',
        (SELECT country_id FROM authorities WHERE id = '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615'),
        '02d4b3f7-b784-4c40-8078-4f0ad36d1590',
        'Test Direct Insert',
        1,
        30,
        30,
        0.0,
        'GBP',
        'f029133e-39cf-4ac4-a04e-25f7b59ef604',
        true,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE 'Direct insert SUCCESS - Table structure is OK';
    
    -- Clean up test data
    DELETE FROM pass_templates WHERE id = test_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Direct insert FAILED: %', SQLERRM;
END;
$$;