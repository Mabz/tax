-- Quick diagnostic for the problem pass
-- Run this to see the current state

SELECT 
    '=== PASS DETAILS ===' as section,
    id,
    current_status,
    entries_remaining,
    entry_limit,
    status as overall_status,
    created_at,
    updated_at
FROM purchased_passes 
WHERE id = '2a9fe188-b6c9-4d83-90e0-48a71f24b3b5'

UNION ALL

SELECT 
    '=== RECENT MOVEMENTS ===' as section,
    movement_type::text as id,
    previous_status as current_status,
    new_status as entries_remaining,
    entries_deducted::text as entry_limit,
    authority_type as overall_status,
    processed_at as created_at,
    processed_at as updated_at
FROM pass_movements 
WHERE pass_id = '2a9fe188-b6c9-4d83-90e0-48a71f24b3b5'
ORDER BY created_at DESC
LIMIT 10;

-- Also check what status values exist in the system
SELECT 
    'STATUS DISTRIBUTION' as info,
    current_status,
    COUNT(*) as count
FROM purchased_passes 
GROUP BY current_status
ORDER BY count DESC;