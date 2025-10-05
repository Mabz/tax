-- Fix purchased_passes table schema
-- This script adds the missing denormalized columns if they don't exist
-- These columns are optional and used for faster queries

-- Check if columns exist and add them if they don't
DO $$ 
BEGIN
    -- Add authority_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'authority_name'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN authority_name TEXT;
        COMMENT ON COLUMN purchased_passes.authority_name IS 'Denormalized authority name for faster queries';
    END IF;

    -- Add country_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'country_name'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN country_name TEXT;
        COMMENT ON COLUMN purchased_passes.country_name IS 'Denormalized country name for faster queries';
    END IF;

    -- Add entry_point_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'entry_point_name'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entry_point_name TEXT;
        COMMENT ON COLUMN purchased_passes.entry_point_name IS 'Denormalized entry point name for faster queries';
    END IF;

    -- Add exit_point_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'exit_point_name'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN exit_point_name TEXT;
        COMMENT ON COLUMN purchased_passes.exit_point_name IS 'Denormalized exit point name for faster queries';
    END IF;
END $$;

-- Update existing passes with authority and country names
UPDATE purchased_passes 
SET 
    authority_name = authorities.name,
    country_name = countries.name,
    updated_at = NOW()
FROM authorities
LEFT JOIN countries ON authorities.country_id = countries.id
WHERE purchased_passes.authority_id = authorities.id
  AND (purchased_passes.authority_name IS NULL OR purchased_passes.country_name IS NULL);

-- Update entry point names separately
UPDATE purchased_passes 
SET 
    entry_point_name = borders.name,
    updated_at = NOW()
FROM borders
WHERE purchased_passes.entry_point_id = borders.id
  AND purchased_passes.entry_point_id IS NOT NULL
  AND purchased_passes.entry_point_name IS NULL;

-- Update exit point names separately  
UPDATE purchased_passes 
SET 
    exit_point_name = borders.name,
    updated_at = NOW()
FROM borders
WHERE purchased_passes.exit_point_id = borders.id
  AND purchased_passes.exit_point_id IS NOT NULL
  AND purchased_passes.exit_point_name IS NULL;

-- Verify the update
SELECT 
    COUNT(*) as total_passes,
    COUNT(authority_name) as passes_with_authority_name,
    COUNT(country_name) as passes_with_country_name,
    COUNT(CASE WHEN entry_point_id IS NOT NULL THEN entry_point_name END) as passes_with_entry_point_name,
    COUNT(CASE WHEN exit_point_id IS NOT NULL THEN exit_point_name END) as passes_with_exit_point_name
FROM purchased_passes;