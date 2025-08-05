-- Fix the countries dropdown to exclude 'All' option
-- Run this in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION get_all_countries_for_selection()
RETURNS TABLE (
  id uuid,
  name text,
  country_code text
) 
LANGUAGE sql
AS $$
  SELECT
    c.id,
    c.name,
    c.country_code
  FROM countries c
  WHERE c.is_active = true
    AND c.name != 'All'
    AND c.name IS NOT NULL
    AND c.name != ''
  ORDER BY c.name;
$$;
