-- Create function to get pass owner's verification preference
-- Run this in your Supabase SQL editor

CREATE OR REPLACE FUNCTION get_pass_owner_verification_preference(pass_id TEXT)
RETURNS TABLE(pass_confirmation_type TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT p.pass_confirmation_type
  FROM profiles p
  JOIN purchased_passes pp ON pp.profile_id = p.id
  WHERE pp.id = pass_id::uuid;  -- Cast text to uuid for proper comparison
END;
$$ LANGUAGE plpgsql;

-- Also create function to get stored PIN
CREATE OR REPLACE FUNCTION get_pass_owner_stored_pin(pass_id TEXT)
RETURNS TABLE(static_confirmation_code TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT p.static_confirmation_code
  FROM profiles p
  JOIN purchased_passes pp ON pp.profile_id = p.id
  WHERE pp.id = pass_id::uuid;  -- Cast text to uuid for proper comparison
END;
$$ LANGUAGE plpgsql;

-- Update the get_passes_for_user function to include secure_code fields
-- Note: This assumes the function exists and needs to be updated
-- You may need to check your existing RPC function and add these fields:
-- secure_code, secure_code_expires_at