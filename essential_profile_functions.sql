-- Essential Profile Management Functions
-- For profiles and countries tables as specified

-- 1. Get identity documents for any profile (preferred function)
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

-- 2. Update current user's full name
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

-- 3. Update current user's identity documents
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

-- 4. Update pass confirmation preference
CREATE OR REPLACE FUNCTION update_pass_confirmation_preference(
  new_confirmation_type text,
  new_static_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate confirmation type
  IF new_confirmation_type NOT IN ('none', 'static_pin', 'dynamic_code') THEN
    RAISE EXCEPTION 'Invalid confirmation type. Must be none, static_pin, or dynamic_code';
  END IF;
  
  -- Validate static code if provided
  IF new_confirmation_type = 'static_pin' AND (new_static_code IS NULL OR length(new_static_code) != 3 OR new_static_code !~ '^[0-9]{3}$') THEN
    RAISE EXCEPTION 'Static PIN must be exactly 3 digits';
  END IF;
  
  UPDATE profiles 
  SET 
    pass_confirmation_type = new_confirmation_type,
    static_confirmation_code = CASE 
      WHEN new_confirmation_type = 'static_pin' THEN new_static_code
      ELSE NULL 
    END,
    updated_at = now()
  WHERE id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;
END;
$$;

-- 5. Update payment details
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

-- 6. Clear payment details
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

-- 7. Get all countries for selection dropdown
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
    AND c.name != 'All'
    AND c.name IS NOT NULL
    AND c.name != ''
  ORDER BY c.name;
$$;

-- Function to generate dynamic confirmation code
CREATE OR REPLACE FUNCTION generate_dynamic_confirmation_code(
  target_pass_id uuid,
  border_official_id uuid
)
RETURNS TABLE(confirmation_code text, expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  code_text text;
  expiry_time timestamptz;
BEGIN
  -- Generate 6-digit code based on timestamp and pass ID
  code_text := LPAD((EXTRACT(EPOCH FROM now())::bigint % 1000000)::text, 6, '0');
  expiry_time := now() + interval '60 seconds';
  
  -- Store the code temporarily (you might want a separate table for this)
  INSERT INTO dynamic_confirmation_codes (
    pass_id, 
    border_official_id, 
    confirmation_code, 
    expires_at,
    created_at
  ) VALUES (
    target_pass_id,
    border_official_id,
    code_text,
    expiry_time,
    now()
  );
  
  RETURN QUERY SELECT code_text, expiry_time;
END;
$$;

-- Function to validate confirmation code
CREATE OR REPLACE FUNCTION validate_pass_confirmation(
  target_pass_id uuid,
  provided_code text,
  border_official_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  profile_rec record;
  is_valid boolean := false;
BEGIN
  -- Get profile confirmation settings
  SELECT p.pass_confirmation_type, p.static_confirmation_code
  INTO profile_rec
  FROM purchased_passes pp
  JOIN profiles p ON p.id = pp.profile_id
  WHERE pp.id = target_pass_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pass not found';
  END IF;
  
  CASE profile_rec.pass_confirmation_type
    WHEN 'none' THEN
      is_valid := true;
      
    WHEN 'static_pin' THEN
      is_valid := (provided_code = profile_rec.static_confirmation_code);
      
    WHEN 'dynamic_code' THEN
      -- Check if valid dynamic code exists and hasn't expired
      SELECT EXISTS(
        SELECT 1 FROM dynamic_confirmation_codes
        WHERE pass_id = target_pass_id
        AND confirmation_code = provided_code
        AND expires_at > now()
        AND used_at IS NULL
      ) INTO is_valid;
      
      -- Mark code as used if valid
      IF is_valid THEN
        UPDATE dynamic_confirmation_codes
        SET used_at = now()
        WHERE pass_id = target_pass_id
        AND confirmation_code = provided_code
        AND used_at IS NULL;
      END IF;
  END CASE;
  
  RETURN is_valid;
END;
$$;

-- Add pass confirmation fields to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pass_confirmation_type text DEFAULT 'none' CHECK (pass_confirmation_type IN ('none', 'static_pin', 'dynamic_code'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS static_confirmation_code text;

-- Table for dynamic confirmation codes (temporary storage)
CREATE TABLE IF NOT EXISTS dynamic_confirmation_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pass_id uuid NOT NULL REFERENCES purchased_passes(id) ON DELETE CASCADE,
  border_official_id uuid NOT NULL REFERENCES auth.users(id),
  confirmation_code text NOT NULL,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_dynamic_codes_pass_code ON dynamic_confirmation_codes(pass_id, confirmation_code);
CREATE INDEX IF NOT EXISTS idx_dynamic_codes_expires ON dynamic_confirmation_codes(expires_at);

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_identity_documents_for_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_full_name(text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_identity_documents(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_confirmation_preference(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_payment_details(text, text, int, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION clear_payment_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_countries_for_selection() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_dynamic_confirmation_code(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_pass_confirmation(uuid, text, uuid) TO authenticated;
