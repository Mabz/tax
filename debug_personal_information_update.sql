-- Debug script to check personal information update issues
-- Run this to see what's happening with phone number and address updates

-- 1. Check if the phone_number and address columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
AND column_name IN ('phone_number', 'address')
ORDER BY column_name;

-- 2. Check if the update_personal_information function exists
SELECT routine_name, routine_type, routine_definition
FROM information_schema.routines 
WHERE routine_name = 'update_personal_information'
AND routine_schema = 'public';

-- 3. Check current profile data structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Test if we can manually update phone_number and address (if columns exist)
-- Replace 'your-user-id' with actual user ID
-- SELECT id, full_name, email, phone_number, address 
-- FROM public.profiles 
-- WHERE id = 'your-user-id';

-- 5. Check if there are any RLS policies that might be blocking updates
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- Instructions:
-- 1. Run this script in your Supabase SQL editor
-- 2. Check the results to see what's missing
-- 3. If phone_number or address columns are missing, run the migration scripts first
-- 4. If the function is missing, create it using create_update_personal_information_function.sql