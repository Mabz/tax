-- Test script for personal information update
-- Run this after creating the function to test if it works

-- 1. Check current user profile (replace with your actual user ID if needed)
SELECT 
    id,
    full_name,
    email,
    phone_number,
    address,
    updated_at
FROM public.profiles 
WHERE id = auth.uid();

-- 2. Test the update function with sample data
-- IMPORTANT: Replace these values with your actual information
-- SELECT update_personal_information(
--     'Your Full Name',
--     'your.email@example.com', 
--     '+268771234567',  -- Test with Eswatini number
--     '123 Your Street, Your City'
-- );

-- 3. Check if the update worked
-- SELECT 
--     id,
--     full_name,
--     email,
--     phone_number,
--     address,
--     updated_at
-- FROM public.profiles 
-- WHERE id = auth.uid();

-- 4. Test with NULL phone and address (should work)
-- SELECT update_personal_information(
--     'Your Full Name',
--     'your.email@example.com', 
--     NULL,  -- No phone number
--     NULL   -- No address
-- );

-- Instructions:
-- 1. First run create_simple_personal_info_update.sql
-- 2. Then uncomment and modify the test calls above with your actual data
-- 3. Run this script to test the function
-- 4. Check if phone_number and address are properly updated