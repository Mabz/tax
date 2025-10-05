-- Add missing columns to pass_templates table

-- Check if is_active column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN is_active BOOLEAN DEFAULT true NOT NULL;
        RAISE NOTICE 'Added is_active column to pass_templates';
    ELSE
        RAISE NOTICE 'is_active column already exists in pass_templates';
    END IF;
END $$;

-- Check if allow_user_selectable_points column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' 
        AND column_name = 'allow_user_selectable_points'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN allow_user_selectable_points BOOLEAN DEFAULT false NOT NULL;
        RAISE NOTICE 'Added allow_user_selectable_points column to pass_templates';
    ELSE
        RAISE NOTICE 'allow_user_selectable_points column already exists in pass_templates';
    END IF;
END $$;

-- Check if pass_advance_days column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' 
        AND column_name = 'pass_advance_days'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN pass_advance_days INTEGER DEFAULT 7 NOT NULL;
        RAISE NOTICE 'Added pass_advance_days column to pass_templates';
    ELSE
        RAISE NOTICE 'pass_advance_days column already exists in pass_templates';
    END IF;
END $$;

-- Update existing templates to have default values
UPDATE pass_templates 
SET 
    is_active = COALESCE(is_active, true),
    allow_user_selectable_points = COALESCE(allow_user_selectable_points, false),
    pass_advance_days = COALESCE(pass_advance_days, 7)
WHERE is_active IS NULL 
   OR allow_user_selectable_points IS NULL 
   OR pass_advance_days IS NULL;