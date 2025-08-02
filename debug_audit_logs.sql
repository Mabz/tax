-- Debug script for audit log functions
-- Run this in your Supabase SQL editor to debug the audit logs

-- 1. Check if audit_logs table exists and has data
SELECT COUNT(*) as total_audit_logs FROM audit_logs;

-- 2. Check the structure of audit_logs table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'audit_logs';

-- 3. Sample some audit logs to see the metadata structure
SELECT id, action, metadata, created_at 
FROM audit_logs 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. Check what country_ids exist in metadata
SELECT DISTINCT metadata ->> 'country_id' as country_id
FROM audit_logs 
WHERE metadata ? 'country_id'
LIMIT 10;

-- 5. Test the basic function (replace with actual country UUID)
-- SELECT * FROM get_audit_logs_by_country('your-actual-country-uuid-here'::uuid);

-- 6. Check if the function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'get_audit_logs_by_country';

-- 7. Test with a sample country ID from your data
-- First, get a real country ID:
SELECT id, name FROM countries LIMIT 3;

-- Then use one of those IDs in the function:
-- SELECT * FROM get_audit_logs_by_country('actual-uuid-from-above'::uuid);