-- Update pass_templates table schema
-- Run this in Supabase SQL Editor

-- Drop the old column
ALTER TABLE pass_templates DROP COLUMN IF EXISTS allow_user_selectable_points;

-- Add the new columns
ALTER TABLE pass_templates ADD COLUMN allow_user_selectable_entry_point BOOLEAN DEFAULT false NOT NULL;
ALTER TABLE pass_templates ADD COLUMN allow_user_selectable_exit_point BOOLEAN DEFAULT false NOT NULL;

-- Show the updated schema
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_templates' 
ORDER BY ordinal_position;