-- Simple personal information update function
-- This version only updates fields that definitely exist and handles missing columns gracefully

-- First, let's make sure the phone_number and address columns exist
DO $$
BEGIN
    -- Add phone_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'phone_number' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN phone_number TEXT NULL;
        
        -- Add constraint for phone number format
        ALTER TABLE public.profiles 
        ADD CONSTRAINT profiles_phone_number_format_check 
        CHECK (
            phone_number IS NULL OR 
            (phone_number ~ '^\+[1-9]\d{1,14}$' AND LENGTH(phone_number) >= 8 AND LENGTH(phone_number) <= 16)
        );
        
        -- Create index
        CREATE INDEX IF NOT EXISTS idx_profiles_phone_number 
        ON public.profiles USING btree (phone_number);
        
        RAISE NOTICE 'Added phone_number column to profiles table';
    END IF;

    -- Add address column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'address' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN address TEXT NULL;
        
        -- Create index
        CREATE INDEX IF NOT EXISTS idx_profiles_address 
        ON public.profiles USING btree (address);
        
        RAISE NOTICE 'Added address column to profiles table';
    END IF;
END $$;

-- Now create the update function
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

-- Test the function (uncomment and replace with actual values to test)
-- SELECT update_personal_information('Test User', 'test@example.com', '+263771234567', '123 Test Street');

RAISE NOTICE 'Personal information update function created successfully';