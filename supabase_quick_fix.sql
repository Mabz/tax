-- Quick fix to add missing authority_id column
BEGIN;

-- Add authority_id to pass_templates if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'authority_id'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN authority_id UUID REFERENCES authorities(id);
        RAISE NOTICE 'Added authority_id column to pass_templates';
    ELSE
        RAISE NOTICE 'authority_id column already exists in pass_templates';
    END IF;
END;
$$;

-- Add country_id to pass_templates if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'country_id'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN country_id UUID REFERENCES countries(id);
        RAISE NOTICE 'Added country_id column to pass_templates';
    ELSE
        RAISE NOTICE 'country_id column already exists in pass_templates';
    END IF;
END;
$$;

COMMIT;