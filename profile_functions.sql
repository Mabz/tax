-- Database functions for Profile Management with the profiles table structure
-- Run these in your Supabase SQL editor

-- Function to get current user's identity documents with country information
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
    c.name as country_name,
    c.country_code,
    p.national_id_number,
    p.passport_number,
    p.updated_at
  FROM profiles p
  LEFT JOIN countries c ON c.id = p.country_of_origin_id
  WHERE p.id = auth.uid();
$$;

-- Function to get identity documents for a specific profile (for border officials)
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
    c.name as country_name,
    c.country_code,
    p.national_id_number,
    p.passport_number,
    p.updated_at
  FROM profiles p
  LEFT JOIN countries c ON c.id = p.country_of_origin_id
  WHERE p.id = profile_id;
$$;

-- Function to update current user's full name
CREATE OR REPLACE FUNCTION update_full_name(new_full_name text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles 
  SET 
    full_name = TRIM(new_full_name),
    updated_at = NOW()
  WHERE id = auth.uid()
    AND TRIM(new_full_name) != '';
$$;

-- Function to update current user's identity documents
CREATE OR REPLACE FUNCTION update_identity_documents(
  new_country_of_origin_id uuid,
  new_national_id_number text,
  new_passport_number text
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles 
  SET 
    country_of_origin_id = new_country_of_origin_id,
    national_id_number = TRIM(new_national_id_number),
    passport_number = TRIM(new_passport_number),
    updated_at = NOW()
  WHERE id = auth.uid();
$$;

-- Function to update pass confirmation preference
CREATE OR REPLACE FUNCTION update_pass_confirmation_preference(require_confirmation boolean)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles 
  SET 
    require_manual_pass_confirmation = require_confirmation,
    updated_at = NOW()
  WHERE id = auth.uid();
$$;

-- Function to update payment details
CREATE OR REPLACE FUNCTION update_payment_details(
  new_card_holder_name text,
  new_card_last4 text,
  new_card_exp_month int,
  new_card_exp_year int,
  new_payment_provider_token text,
  new_payment_provider text
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles 
  SET 
    card_holder_name = TRIM(new_card_holder_name),
    card_last4 = TRIM(new_card_last4),
    card_exp_month = new_card_exp_month,
    card_exp_year = new_card_exp_year,
    payment_provider_token = TRIM(new_payment_provider_token),
    payment_provider = TRIM(new_payment_provider),
    updated_at = NOW()
  WHERE id = auth.uid();
$$;

-- Function to clear payment details
CREATE OR REPLACE FUNCTION clear_payment_details()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles 
  SET 
    card_holder_name = NULL,
    card_last4 = NULL,
    card_exp_month = NULL,
    card_exp_year = NULL,
    payment_provider_token = NULL,
    payment_provider = NULL,
    updated_at = NOW()
  WHERE id = auth.uid();
$$;

-- Function to get all countries for selection dropdown
CREATE OR REPLACE FUNCTION get_all_countries_for_selection()
RETURNS TABLE (
  id uuid,
  name text,
  country_code text
) 
LANGUAGE sql
AS $$
  SELECT
    c.id,
    c.name,
    c.country_code
  FROM countries c
  WHERE c.is_active = true
  ORDER BY c.name;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_my_identity_documents() TO authenticated;
GRANT EXECUTE ON FUNCTION get_identity_documents_for_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_full_name(text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_identity_documents(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_confirmation_preference(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION update_payment_details(text, text, int, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION clear_payment_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_countries_for_selection() TO authenticated;
