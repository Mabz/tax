-- ============================================================================
-- PROFILE MANAGEMENT DATABASE FUNCTIONS
-- PURPOSE: Complete set of functions for user profile management
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
-- PURPOSE: Allows an authenticated user to update their nationality,
--   national ID, and passport number.
-- ============================================================================
CREATE OR REPLACE FUNCTION update_identity_documents(
  new_nationality text,
  new_national_id_number text,
  new_passport_number text
)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
  UPDATE profiles
  SET nationality = new_nationality,
      national_id_number = new_national_id_number,
      passport_number = new_passport_number,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$;

-- ============================================================================
-- FUNCTION: get_my_identity_documents
-- PURPOSE: Retrieves the current user's saved nationality, ID, and passport info.
-- ============================================================================
CREATE OR REPLACE FUNCTION get_my_identity_documents()
RETURNS TABLE (
  nationality text,
  national_id_number text,
  passport_number text,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY definer
STABLE
AS $$
  SELECT 
    nationality,
    national_id_number,
    passport_number,
    updated_at
  FROM profiles
  WHERE id = auth.uid();
$$;

-- ============================================================================
-- FUNCTION: get_identity_documents_for_profile
-- PURPOSE: Allows a border official to retrieve a specific profile's identity info.
--   Intended for scanning contexts (use RLS to restrict access).
-- ============================================================================
CREATE OR REPLACE FUNCTION get_identity_documents_for_profile(
  target_profile_id uuid
)
RETURNS TABLE (
  full_name text,
  nationality text,
  national_id_number text,
  passport_number text,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY definer
STABLE
AS $$
  SELECT 
    full_name,
    nationality,
    national_id_number,
    passport_number,
    updated_at
  FROM profiles
  WHERE id = target_profile_id;
$$;

-- ============================================================================
-- FUNCTION: update_pass_confirmation_preference
-- PURPOSE: Allows the user to enable/disable manual pass confirmation at scanning.
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
  SET require_manual_pass_confirmation = require_confirmation,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$;

-- ============================================================================
-- FUNCTION: update_payment_details
-- PURPOSE: Saves card metadata for recurrent or reference-based payments.
--   Note: CVV and full card numbers should never be stored.
-- ============================================================================
CREATE OR REPLACE FUNCTION update_payment_details(
  new_card_holder_name text,
  new_card_last4 text,
  new_card_exp_month int,
  new_card_exp_year int,
  new_payment_provider_token text,
  new_payment_provider text
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
      payment_provider_token = new_payment_provider_token,
      payment_provider = new_payment_provider,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$;

-- ============================================================================
-- FUNCTION: clear_payment_details
-- PURPOSE: Wipes all stored payment data for the current profile.
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
END;
$$;

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Only allow a user to read/update their own identity
CREATE POLICY "Users can edit their own identity"
ON profiles FOR UPDATE USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Allow users to read their own profile data
CREATE POLICY "Users can read their own profile"
ON profiles FOR SELECT USING (auth.uid() = id);

-- Allow border officials to read identity documents for verification
-- (This would need additional RLS based on border official roles)
CREATE POLICY "Border officials can read identity documents"
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
GRANT EXECUTE ON FUNCTION update_pass_confirmation_preference TO authenticated;
GRANT EXECUTE ON FUNCTION update_payment_details TO authenticated;
GRANT EXECUTE ON FUNCTION clear_payment_details TO authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION update_full_name IS 'Updates current user full name with validation';
COMMENT ON FUNCTION update_identity_documents IS 'Updates current user identity documents (nationality, national ID, passport)';
COMMENT ON FUNCTION get_my_identity_documents IS 'Retrieves current user identity documents';
COMMENT ON FUNCTION get_identity_documents_for_profile IS 'Allows border officials to view profile identity documents';
COMMENT ON FUNCTION update_pass_confirmation_preference IS 'Updates user preference for manual pass confirmation';
COMMENT ON FUNCTION update_payment_details IS 'Saves payment method metadata (no sensitive card data)';
COMMENT ON FUNCTION clear_payment_details IS 'Removes all saved payment information for current user';
