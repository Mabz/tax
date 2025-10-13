-- Create function to update user's phone number
-- This function allows users to update their phone number with proper validation

CREATE OR REPLACE FUNCTION update_phone_number(new_phone_number TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Check if user is authenticateda
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Validate phone number format if provided
    IF new_phone_number IS NOT NULL AND new_phone_number != '' THEN
        -- Check if phone number starts with + and has valid format
        IF NOT (new_phone_number ~ '^\+[1-9]\d{1,14}$' AND LENGTH(new_phone_number) >= 8 AND LENGTH(new_phone_number) <= 16) THEN
            RAISE EXCEPTION 'Invalid phone number format. Must be in international format (e.g., +263771234567)';
        END IF;
    END IF;

    -- Update the phone number in profiles table
    UPDATE public.profiles 
    SET 
        phone_number = CASE 
            WHEN new_phone_number = '' THEN NULL 
            ELSE new_phone_number 
        END,
        updated_at = NOW()
    WHERE id = current_user_id;

    -- Check if the update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found for user';
    END IF;

    -- Log the update (optional)
    RAISE NOTICE 'Phone number updated successfully for user %', current_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_phone_number(TEXT) TO authenticated;

-- Add comment to document the function
COMMENT ON FUNCTION update_phone_number(TEXT) IS 'Updates the phone number for the current authenticated user with validation';

-- Example usage:
-- SELECT update_phone_number('+263771234567');  -- Set phone number
-- SELECT update_phone_number(NULL);             -- Remove phone number
-- SELECT update_phone_number('');               -- Remove phone number (empty string)