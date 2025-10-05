-- Fix pass templates with user-selectable points
-- When allow_user_selectable_points is true, entry_point_id and exit_point_id should be null

-- First, let's see what we're working with
SELECT 
    id,
    description,
    allow_user_selectable_points,
    entry_point_id,
    exit_point_id,
    CASE 
        WHEN allow_user_selectable_points = true AND (entry_point_id IS NOT NULL OR exit_point_id IS NOT NULL) 
        THEN 'NEEDS_FIX'
        ELSE 'OK'
    END as status
FROM pass_templates
WHERE allow_user_selectable_points = true;

-- Update templates with user-selectable points to have null entry/exit point IDs
UPDATE pass_templates 
SET 
    entry_point_id = NULL,
    exit_point_id = NULL,
    updated_at = NOW()
WHERE allow_user_selectable_points = true
  AND (entry_point_id IS NOT NULL OR exit_point_id IS NOT NULL);

-- Verify the fix
SELECT 
    COUNT(*) as total_user_selectable_templates,
    COUNT(CASE WHEN entry_point_id IS NULL AND exit_point_id IS NULL THEN 1 END) as properly_configured,
    COUNT(CASE WHEN entry_point_id IS NOT NULL OR exit_point_id IS NOT NULL THEN 1 END) as needs_attention
FROM pass_templates
WHERE allow_user_selectable_points = true;

-- Show any remaining problematic templates
SELECT 
    id,
    description,
    entry_point_id,
    exit_point_id,
    'Still has fixed points despite user-selectable setting' as issue
FROM pass_templates
WHERE allow_user_selectable_points = true
  AND (entry_point_id IS NOT NULL OR exit_point_id IS NOT NULL);