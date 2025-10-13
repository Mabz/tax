-- Add phone_number column to profiles table
-- This will allow users to store their phone number with proper validation

-- Add the phone_number column
ALTER TABLE public.profiles 
ADD COLUMN phone_number TEXT NULL;

-- Add a check constraint to ensure phone numbers start with + and country code
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_phone_number_format_check 
CHECK (
  phone_number IS NULL OR 
  (phone_number ~ '^\+[1-9]\d{1,14}$' AND LENGTH(phone_number) >= 8 AND LENGTH(phone_number) <= 16)
);

-- Create an index for phone number lookups (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number 
ON public.profiles USING btree (phone_number) 
TABLESPACE pg_default;

-- Add comment to document the column
COMMENT ON COLUMN public.profiles.phone_number IS 'User phone number in international format (e.g., +263771234567)';

-- Update the updated_at timestamp when phone_number changes
-- This assumes you have a trigger for updated_at, if not, you can add one

-- Example valid phone numbers after this migration:
-- +263771234567 (Zimbabwe)
-- +27821234567 (South Africa)
-- +1234567890 (US - but needs proper formatting)
-- +447911123456 (UK)

-- Invalid examples that will be rejected:
-- 0771234567 (no country code)
-- +263 77 123 4567 (spaces not allowed)
-- 263771234567 (missing +)
-- +263 (too short)