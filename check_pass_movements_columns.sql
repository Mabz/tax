-- Check what columns exist in pass_movements table to identify profile links

-- 1. Show all columns in pass_movements table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_movements' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Look for columns that might link to profiles (containing 'id')
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'pass_movements' 
AND table_schema = 'public'
AND (column_name LIKE '%id%' OR column_name LIKE '%by%')
ORDER BY column_name;

-- 3. Check foreign key relationships
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'pass_movements'
AND ccu.table_name = 'profiles';

-- 4. Sample data to see what's actually in the table
SELECT * FROM pass_movements LIMIT 3;