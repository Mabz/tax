-- ============================================================================
-- UPDATED PROFILE MANAGEMENT FUNCTIONS WITH COUNTRY OF ORIGIN
-- These functions replace the nationality field with country_of_origin_id
-- linked to the countries table
-- ============================================================================

-- ============================================================================
-- FUNCTION: update_full_name
-- PURPOSE: Allows an authenticated user to update their full name
-- ============================================================================
CREATE OR REPLACE FUNCTION update_full_name(
  new_full_name text
)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  -- Validate that the name is not empty
  IF new_full_name IS NULL OR trim(new_full_name) = '' THEN
    RAISE EXCEPTION 'Full name cannot be empty';
  END IF;

  -- Update the user's full name
  UPDATE profiles
  SET full_name = trim(new_full_name),
      updated_at = now()
  WHERE id = auth.uid();
  
  -- Check if the update affected any rows
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found or user not authenticated';
  END IF;
END;
$$;

-- ============================================================================
-- FUNCTION: update_identity_documents
-- PURPOSE: Allows an authenticated user to update their country of origin,
--          national ID, and passport number
-- ============================================================================
CREATE OR REPLACE FUNCTION update_identity_documents(
  new_country_of_origin_id uuid,
  new_national_id_number text,
  new_passport_number text
)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  -- Validate that country exists and is not null
  IF new_country_of_origin_id IS NULL THEN
    RAISE EXCEPTION 'Country of origin is required';
  END IF;
  
  -- Verify the country exists (ignoring is_active as requested)
  IF NOT EXISTS (
    SELECT 1 FROM countries 
    WHERE id = new_country_of_origin_id
  ) THEN
    RAISE EXCEPTION 'Invalid country of origin selected';
  END IF;

  -- Validate required fields
  IF new_national_id_number IS NULL OR trim(new_national_id_number) = '' THEN
    RAISE EXCEPTION 'National ID number is required';
  END IF;

  IF new_passport_number IS NULL OR trim(new_passport_number) = '' THEN
    RAISE EXCEPTION 'Passport number is required';
  END IF;

  -- Update the identity documents
  UPDATE profiles
  SET country_of_origin_id = new_country_of_origin_id,
      national_id_number = trim(new_national_id_number),
      passport_number = trim(new_passport_number),
      updated_at = now()
  WHERE id = auth.uid();
  
  -- Check if the update affected any rows
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found or user not authenticated';
  END IF;
END;
$$;

-- ============================================================================
-- FUNCTION: get_my_identity_documents
-- PURPOSE: Retrieves the current user's identity documents with country info
-- ============================================================================
CREATE OR REPLACE FUNCTION get_my_identity_documents()
RETURNS TABLE(
  country_of_origin_id uuid,
  country_name text,
  country_code text,
  national_id_number text,
  passport_number text,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.country_of_origin_id,
    c.name as country_name,
    c.country_code,
    p.national_id_number,
    p.passport_number,
    p.updated_at
  FROM profiles p
  LEFT JOIN countries c ON c.id = p.country_of_origin_id
  WHERE p.id = auth.uid();
END;
$$;

-- ============================================================================
-- FUNCTION: get_identity_documents_for_profile
-- PURPOSE: Allows border officials to view identity documents for a profile
-- ============================================================================
CREATE OR REPLACE FUNCTION get_identity_documents_for_profile(profile_id uuid)
RETURNS TABLE(
  country_of_origin_id uuid,
  country_name text,
  country_code text,
  national_id_number text,
  passport_number text,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  -- Check if user has border official role
  IF NOT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
    AND r.name = 'border_official'
    AND ur.is_active = true
  ) THEN
    RAISE EXCEPTION 'Access denied: Border official role required';
  END IF;

  RETURN QUERY
  SELECT 
    p.country_of_origin_id,
    c.name as country_name,
    c.country_code,
    p.national_id_number,
    p.passport_number,
    p.updated_at
  FROM profiles p
  LEFT JOIN countries c ON c.id = p.country_of_origin_id
  WHERE p.id = profile_id;
END;
$$;

-- ============================================================================
-- FUNCTION: get_all_countries_for_selection
-- PURPOSE: Get all countries for dropdown selection (ignoring is_active)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_all_countries_for_selection()
RETURNS TABLE(
  id uuid,
  name text,
  country_code text
)
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.name,
    c.country_code
  FROM countries c
  ORDER BY c.name;
END;
$$;

-- ============================================================================
-- FUNCTION: update_pass_confirmation_preference
-- PURPOSE: Updates user preference for manual pass confirmation
-- ============================================================================
CREATE OR REPLACE FUNCTION update_pass_confirmation_preference(
  require_confirmation boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  UPDATE profiles
  SET require_pass_confirmation = require_confirmation,
      updated_at = now()
  WHERE id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found or user not authenticated';
  END IF;
END;
$$;

-- ============================================================================
-- FUNCTION: update_payment_details
-- PURPOSE: Saves payment method metadata (no sensitive card data)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_payment_details(
  new_card_holder_name text,
  new_card_last4 text,
  new_card_exp_month integer,
  new_card_exp_year integer,
  new_payment_provider text,
  new_payment_provider_token text
)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  UPDATE profiles
  SET card_holder_name = new_card_holder_name,
      card_last4 = new_card_last4,
      card_exp_month = new_card_exp_month,
      card_exp_year = new_card_exp_year,
      payment_provider = new_payment_provider,
      payment_provider_token = new_payment_provider_token,
      updated_at = now()
  WHERE id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found or user not authenticated';
  END IF;
END;
$$;

-- ============================================================================
-- FUNCTION: clear_payment_details
-- PURPOSE: Wipes all stored payment data for the current profile
-- ============================================================================
CREATE OR REPLACE FUNCTION clear_payment_details()
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  UPDATE profiles
  SET card_holder_name = null,
      card_last4 = null,
      card_exp_month = null,
      card_exp_year = null,
      payment_provider_token = null,
      payment_provider = null,
      updated_at = now()
  WHERE id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found or user not authenticated';
  END IF;
END;
$$;

-- ============================================================================
-- RLS POLICIES (if not already created)
-- ============================================================================

-- Allow border officials to view identity documents
DROP POLICY IF EXISTS "border_officials_can_view_identity_documents" ON profiles;
CREATE POLICY "border_officials_can_view_identity_documents"
ON profiles FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
    AND r.name = 'border_official'
    AND ur.is_active = true
  )
);

-- ============================================================================
-- GRANTS
-- ============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION update_full_name TO authenticated;
GRANT EXECUTE ON FUNCTION update_identity_documents TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_identity_documents TO authenticated;
GRANT EXECUTE ON FUNCTION get_identity_documents_for_profile TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_countries_for_selection TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_confirmation_preference TO authenticated;
GRANT EXECUTE ON FUNCTION update_payment_details TO authenticated;
GRANT EXECUTE ON FUNCTION clear_payment_details TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION update_full_name IS 'Updates current user full name with validation';
COMMENT ON FUNCTION update_identity_documents IS 'Updates current user identity documents (country of origin, national ID, passport)';
COMMENT ON FUNCTION get_my_identity_documents IS 'Retrieves current user identity documents with country information';
COMMENT ON FUNCTION get_identity_documents_for_profile IS 'Allows border officials to view profile identity documents';
COMMENT ON FUNCTION get_all_countries_for_selection IS 'Returns all countries for dropdown selection (ignores is_active)';
COMMENT ON FUNCTION update_pass_confirmation_preference IS 'Updates user preference for manual pass confirmation';
COMMENT ON FUNCTION update_payment_details IS 'Saves payment method metadata (no sensitive card data)';
COMMENT ON FUNCTION clear_payment_details IS 'Removes all saved payment information for current user';

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- 
-- Before running these functions, ensure your profiles table has:
-- 1. country_of_origin_id UUID column (foreign key to countries.id)
-- 2. Remove or rename the old nationality column if it exists
-- 
-- Example migration SQL:
-- ALTER TABLE profiles ADD COLUMN country_of_origin_id UUID REFERENCES countries(id);
-- ALTER TABLE profiles DROP COLUMN nationality; -- if it exists
--
-- ============================================================================
