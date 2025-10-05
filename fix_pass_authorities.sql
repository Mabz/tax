-- Fix passes with missing authority information
-- This script updates purchased_passes records that have authority_id but missing authority_name

-- First, let's see what we're working with
SELECT 
    pp.id,
    pp.authority_id,
    pp.authority_name,
    pp.country_name,
    a.name as actual_authority_name,
    c.name as actual_country_name
FROM purchased_passes pp
LEFT JOIN authorities a ON pp.authority_id = a.id
LEFT JOIN countries c ON a.country_id = c.id
WHERE pp.authority_id IS NOT NULL 
  AND (pp.authority_name IS NULL OR pp.authority_name = '' OR pp.authority_name = 'Unknown Authority');

-- Update passes with missing authority names
UPDATE purchased_passes 
SET 
    authority_name = authorities.name,
    country_name = countries.name,
    updated_at = NOW()
FROM authorities
LEFT JOIN countries ON authorities.country_id = countries.id
WHERE purchased_passes.authority_id = authorities.id
  AND purchased_passes.authority_id IS NOT NULL
  AND (purchased_passes.authority_name IS NULL 
       OR purchased_passes.authority_name = '' 
       OR purchased_passes.authority_name = 'Unknown Authority');

-- Verify the fix
SELECT 
    COUNT(*) as total_passes,
    COUNT(CASE WHEN authority_name IS NOT NULL AND authority_name != '' AND authority_name != 'Unknown Authority' THEN 1 END) as passes_with_authority,
    COUNT(CASE WHEN authority_name IS NULL OR authority_name = '' OR authority_name = 'Unknown Authority' THEN 1 END) as passes_without_authority
FROM purchased_passes
WHERE authority_id IS NOT NULL;

-- Show any remaining problematic passes
SELECT 
    pp.id,
    pp.authority_id,
    pp.authority_name,
    pp.pass_description,
    'Authority not found' as issue
FROM purchased_passes pp
LEFT JOIN authorities a ON pp.authority_id = a.id
WHERE pp.authority_id IS NOT NULL 
  AND a.id IS NULL;

-- Show passes with null authority_id (these may need manual review)
SELECT 
    id,
    pass_description,
    created_at,
    'Null authority_id' as issue
FROM purchased_passes 
WHERE authority_id IS NULL
ORDER BY created_at DESC
LIMIT 10;