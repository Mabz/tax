-- Just check the columns in pass_templates
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'pass_templates'
ORDER BY ordinal_position;