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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_full_name TO authenticated;

-- Add comment
COMMENT ON FUNCTION update_full_name IS 'Updates the current user full name with validation';
