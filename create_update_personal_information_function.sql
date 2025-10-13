-- Create function to update user's personal information
-- This function allows users to update their full name, email, phone number, and address in one call

CREATE OR REPLACE FUNCTION update_personal_information(
    new_full_name TEXT,
    new_email TEXT,
    new_phone_number TEXT DEFAULT NULL,
    new_address TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Validate required fields
    IF new_full_name IS NULL OR TRIM(new_full_name) = '' THEN
        RAISE EXCEPTION 'Full name is required';
    END IF;

    IF new_email IS NULL OR TRIM(new_email) = '' THEN
        RAISE EXCEPTION 'Email address is required';
    END IF;

    -- Validate email format (basic validation)
    IF NOT (new_email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') THEN
        RAISE EXCEPTION 'Invalid email address format';
    END IF;

    -- Validate phone number format if provided
    IF new_phone_number IS NOT NULL AND new_phone_number != '' THEN
        -- Check if phone number starts with + and has valid format
        IF NOT (new_phone_number ~ '^\+[1-9]\d{1,14}$' AND LENGTH(new_phone_number) >= 8 AND LENGTH(new_phone_number) <= 16) THEN
            RAISE EXCEPTION 'Invalid phone number format. Must be in international format (e.g., +263771234567)';
        END IF;
    END IF;

    -- Check if email is already taken by another user
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE email = new_email AND id != current_user_id
    ) THEN
        RAISE EXCEPTION 'Email address is already in use by another account';
    END IF;

    -- Update the personal information in profiles table
    UPDATE public.profiles 
    SET 
        full_name = TRIM(new_full_name),
        email = LOWER(TRIM(new_email)),
        phone_number = CASE 
            WHEN new_phone_number = '' THEN NULL 
            ELSE new_phone_number 
        END,
        address = CASE 
            WHEN new_address = '' THEN NULL 
            ELSE TRIM(new_address) 
        END,
        updated_at = NOW()
    WHERE id = current_user_id;

    -- Check if the update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found for user';
    END IF;

    -- Also update the email in auth.users table for consistency
    UPDATE auth.users 
    SET 
        email = LOWER(TRIM(new_email)),
        updated_at = NOW()
    WHERE id = current_user_id;

    -- Log the update (optional)
    RAISE NOTICE 'Personal information updated successfully for user %', current_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_personal_information(TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Add comment to document the function
COMMENT ON FUNCTION update_personal_information(TEXT, TEXT, TEXT, TEXT) IS 'Updates personal information (full name, email, phone, address) for the current authenticated user with validation';

-- Example usage:
-- SELECT update_personal_information('John Smith', 'john@example.com', '+263771234567', '123 Main St, Harare');
-- SELECT update_personal_information('Jane Doe', 'jane@example.com', NULL, NULL);  -- No phone or address