-- Fix the update_pass_confirmation_preference function
-- Run this in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION update_pass_confirmation_preference(
  pass_confirmation_type text,
  static_confirmation_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validate confirmation type
  IF pass_confirmation_type NOT IN ('none', 'staticPin', 'dynamicCode') THEN
    RAISE EXCEPTION 'Invalid confirmation type. Must be none, staticPin, or dynamicCode';
  END IF;
  
  -- Validate static code if provided
  IF pass_confirmation_type = 'staticPin' AND (static_confirmation_code IS NULL OR length(static_confirmation_code) != 3 OR static_confirmation_code !~ '^[0-9]{3}$') THEN
    RAISE EXCEPTION 'Static PIN must be exactly 3 digits';
  END IF;
  
  UPDATE profiles 
  SET 
    pass_confirmation_type = update_pass_confirmation_preference.pass_confirmation_type,
    static_confirmation_code = CASE 
      WHEN update_pass_confirmation_preference.pass_confirmation_type = 'staticPin' THEN update_pass_confirmation_preference.static_confirmation_code
      ELSE NULL 
    END,
    updated_at = now()
  WHERE id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;
END;
$$;
