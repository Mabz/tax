-- Fix the relationship between purchased_passes and pass_templates
-- This resolves the "Could not find a relationship" error

-- First, check if the pass_template_id column exists in purchased_passes
DO $$
BEGIN
    -- Add pass_template_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'pass_template_id'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN pass_template_id UUID REFERENCES pass_templates(id);
        RAISE NOTICE 'Added pass_template_id column to purchased_passes';
    ELSE
        RAISE NOTICE 'pass_template_id column already exists in purchased_passes';
    END IF;

    -- Ensure the foreign key constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'purchased_passes' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'pass_template_id'
        AND ccu.table_name = 'pass_templates'
    ) THEN
        -- Drop existing constraint if it exists but is malformed
        ALTER TABLE purchased_passes DROP CONSTRAINT IF EXISTS purchased_passes_pass_template_id_fkey;
        
        -- Add the proper foreign key constraint
        ALTER TABLE purchased_passes 
        ADD CONSTRAINT purchased_passes_pass_template_id_fkey 
        FOREIGN KEY (pass_template_id) REFERENCES pass_templates(id);
        
        RAISE NOTICE 'Added foreign key constraint for pass_template_id';
    ELSE
        RAISE NOTICE 'Foreign key constraint already exists for pass_template_id';
    END IF;
END;
$$;

-- Refresh the schema cache by running a simple query
SELECT 1 FROM purchased_passes LIMIT 1;
SELECT 1 FROM pass_templates LIMIT 1;

-- Test the relationship by running a sample join query
DO $$
DECLARE
    test_count INTEGER;
BEGIN
    -- Test if the relationship works
    SELECT COUNT(*) INTO test_count
    FROM purchased_passes pp
    LEFT JOIN pass_templates pt ON pp.pass_template_id = pt.id
    LIMIT 1;
    
    RAISE NOTICE 'Schema relationship test completed successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Schema relationship test failed: %', SQLERRM;
END;
$$;

-- Show current schema information
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS referenced_table_name,
    ccu.column_name AS referenced_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name IN ('purchased_passes', 'pass_templates')
AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, kcu.column_name;