-- ============================================================================
-- DATABASE TEST SCRIPT FOR PROFILE MANAGEMENT
-- Run these queries in your Supabase SQL editor to test the functions
-- ============================================================================

-- 1. Check if countries table has data
SELECT 'Countries count:' as test, COUNT(*) as result FROM countries;
SELECT 'Sample countries:' as test, name, country_code FROM countries LIMIT 5;

-- 2. Test get_all_countries_for_selection function
SELECT 'Testing get_all_countries_for_selection function:' as test;
SELECT * FROM get_all_countries_for_selection() LIMIT 5;

-- 3. Check if the function exists
SELECT 'Function exists:' as test, 
       CASE WHEN EXISTS (
         SELECT 1 FROM pg_proc 
         WHERE proname = 'get_all_countries_for_selection'
       ) THEN 'YES' ELSE 'NO' END as result;

-- 4. Check profiles table structure
SELECT 'Profiles table columns:' as test;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;

-- 5. Test get_my_identity_documents function (if you're authenticated)
SELECT 'Testing get_my_identity_documents function:' as test;
-- This will only work if you're authenticated in Supabase
-- SELECT * FROM get_my_identity_documents();

-- ============================================================================
-- IF COUNTRIES TABLE IS EMPTY, RUN THIS TO ADD SAMPLE DATA:
-- ============================================================================

INSERT INTO countries (id, name, country_code, is_active) VALUES
  (gen_random_uuid(), 'United States', 'US', true),
  (gen_random_uuid(), 'United Kingdom', 'GB', true),
  (gen_random_uuid(), 'Canada', 'CA', true),
  (gen_random_uuid(), 'Australia', 'AU', true),
  (gen_random_uuid(), 'Germany', 'DE', true),
  (gen_random_uuid(), 'France', 'FR', true),
  (gen_random_uuid(), 'Japan', 'JP', true),
  (gen_random_uuid(), 'South Africa', 'ZA', true),
  (gen_random_uuid(), 'Brazil', 'BR', true),
  (gen_random_uuid(), 'India', 'IN', true)
ON CONFLICT (country_code) DO NOTHING;

-- ============================================================================
-- ENSURE THE FUNCTION EXISTS AND HAS PROPER PERMISSIONS:
-- ============================================================================

CREATE OR REPLACE FUNCTION get_all_countries_for_selection()
RETURNS TABLE (
  id uuid,
  name text,
  country_code text
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id, name, country_code
  FROM countries
  WHERE is_active = true
  ORDER BY name;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_all_countries_for_selection() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_countries_for_selection() TO anon;

-- Test the function again
SELECT 'Final test - get_all_countries_for_selection:' as test;
SELECT * FROM get_all_countries_for_selection();
