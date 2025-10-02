-- =====================================================
-- Schema Diagnostic Script
-- =====================================================
-- This script checks what columns currently exist in your tables

-- Check pass_templates table structure
SELECT 
    'pass_templates' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_templates'
ORDER BY ordinal_position;

-- Check purchased_passes table structure  
SELECT 
    'purchased_passes' as table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'purchased_passes'
ORDER BY ordinal_position;

-- Check if the functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name IN (
    'create_pass_template',
    'update_pass_template', 
    'get_pass_templates_for_authority',
    'issue_pass_from_template'
)
ORDER BY routine_name;