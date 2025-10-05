-- Check the actual schema of pass_templates table
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_templates' 
ORDER BY ordinal_position;

-- Also check if the function already exists
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name LIKE '%pass_template%';

-- Check existing pass templates to see the data structure
SELECT 
    id,
    description,
    entry_limit,
    expiration_days,
    pass_advance_days,
    tax_amount,
    currency_code,
    is_active,
    allow_user_selectable_points,
    entry_point_id,
    exit_point_id,
    vehicle_type_id,
    created_at,
    updated_at
FROM pass_templates 
LIMIT 3;