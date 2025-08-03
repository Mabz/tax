-- ============================================================================
-- FIX IDENTITY DOCUMENTS FUNCTIONS - TYPE MISMATCH ISSUE
-- Run this in your Supabase SQL editor to fix the type mismatch errors
-- ============================================================================

-- Drop existing functions to recreate them with correct types
DROP FUNCTION IF EXISTS get_my_identity_documents();
DROP FUNCTION IF EXISTS get_identity_documents_for_profile(uuid);

-- ============================================================================
-- 1. Fix get_my_identity_documents function
-- ============================================================================
CREATE OR REPLACE FUNCTION get_my_identity_documents()
RETURNS TABLE (
  country_of_origin_id uuid,
  country_name text,
  country_code text,
  national_id_number text,
  passport_number text,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    p.country_of_origin_id,
    COALESCE(c.name, '')::text as country_name,
    COALESCE(c.country_code, '')::text as country_code,
    COALESCE(p.national_id_number, '')::text as national_id_number,
    COALESCE(p.passport_number, '')::text as passport_number,
    p.updated_at
  FROM profiles p
  LEFT JOIN countries c ON p.country_of_origin_id = c.id
  WHERE p.id = auth.uid();
$$;

-- ============================================================================
-- 2. Fix get_identity_documents_for_profile function (for border officials)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_identity_documents_for_profile(profile_id uuid)
RETURNS TABLE (
  country_of_origin_id uuid,
  country_name text,
  country_code text,
  national_id_number text,
  passport_number text,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    p.country_of_origin_id,
    COALESCE(c.name, '')::text as country_name,
    COALESCE(c.country_code, '')::text as country_code,
    COALESCE(p.national_id_number, '')::text as national_id_number,
    COALESCE(p.passport_number, '')::text as passport_number,
    p.updated_at
  FROM profiles p
  LEFT JOIN countries c ON p.country_of_origin_id = c.id
  WHERE p.id = profile_id;
$$;

-- ============================================================================
-- 3. Grant proper permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION get_my_identity_documents() TO authenticated;
GRANT EXECUTE ON FUNCTION get_identity_documents_for_profile(uuid) TO authenticated;

-- ============================================================================
-- 4. Test the functions
-- ============================================================================
SELECT 'Testing get_my_identity_documents:' as test;
-- This will only work if you're authenticated
-- SELECT * FROM get_my_identity_documents();

SELECT 'Testing get_identity_documents_for_profile with a sample UUID:' as test;
-- Replace with an actual profile UUID to test
-- SELECT * FROM get_identity_documents_for_profile('00000000-0000-0000-0000-000000000000');

-- ============================================================================
-- 5. Check function signatures
-- ============================================================================
SELECT 
  'Function signatures:' as info,
  proname as function_name,
  pg_get_function_result(oid) as return_type
FROM pg_proc 
WHERE proname IN ('get_my_identity_documents', 'get_identity_documents_for_profile');
