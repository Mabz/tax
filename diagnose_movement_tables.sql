-- Comprehensive diagnosis of movement-related tables

-- 1. Check pass_movements table structure
SELECT 'pass_movements columns:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_movements' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check borders table structure
SELECT 'borders columns:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'borders' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check authorities table structure
SELECT 'authorities columns:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'authorities' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check foreign key relationships for pass_movements
SELECT 'pass_movements foreign keys:' as info;
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
AND tc.table_name = 'pass_movements';

-- 5. Sample data from pass_movements (first 3 rows)
SELECT 'Sample pass_movements data:' as info;
SELECT * FROM pass_movements LIMIT 3;