-- Add missing exit_point_name column to purchased_passes table
-- This ensures exit point information is properly stored and displayed

DO $$
BEGIN
    -- Add exit_point_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'exit_point_name'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN exit_point_name TEXT;
        RAISE NOTICE 'Added exit_point_name column to purchased_passes';
    ELSE
        RAISE NOTICE 'exit_point_name column already exists in purchased_passes';
    END IF;

    -- Also ensure entry_point_name column exists (in case it's missing too)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'entry_point_name'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entry_point_name TEXT;
        RAISE NOTICE 'Added entry_point_name column to purchased_passes';
    ELSE
        RAISE NOTICE 'entry_point_name column already exists in purchased_passes';
    END IF;
END;
$$;

-- Update existing passes to populate exit_point_name from borders table
UPDATE purchased_passes 
SET exit_point_name = b.name
FROM borders b
WHERE purchased_passes.exit_point_id = b.id 
AND purchased_passes.exit_point_name IS NULL;

-- Update existing passes to populate entry_point_name from borders table (if missing)
UPDATE purchased_passes 
SET entry_point_name = b.name
FROM borders b
WHERE purchased_passes.entry_point_id = b.id 
AND purchased_passes.entry_point_name IS NULL;

-- Show current schema for purchased_passes table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'purchased_passes'
AND column_name IN ('entry_point_name', 'exit_point_name', 'entry_point_id', 'exit_point_id')
ORDER BY column_name;