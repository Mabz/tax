-- Add address column to profiles table
-- This will allow users to store their residential address

-- Add the address column
ALTER TABLE public.profiles 
ADD COLUMN address TEXT NULL;

-- Create an index for address searches (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_profiles_address 
ON public.profiles USING btree (address) 
TABLESPACE pg_default;

-- Add comment to document the column
COMMENT ON COLUMN public.profiles.address IS 'User residential address for contact and verification purposes';

-- Note: Email is already in the profiles table, so no need to add it