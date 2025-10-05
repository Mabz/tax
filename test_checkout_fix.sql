-- Test the checkout logic fix
-- Run this after running fix_checkout_logic.sql

-- Show current passes with their status
SELECT 
    'Current Pass Status' as info,
    id,
    pass_description,
    current_status,
    entries_remaining,
    get_pass_display_status(entries_remaining, current_status, status, expires_at, activation_date) as display_status
FROM purchased_passes 
WHERE status = 'active'
ORDER BY current_status, entries_remaining;

-- Test the checkout with zero entries function
SELECT test_checkout_with_zero_entries() as test_result;