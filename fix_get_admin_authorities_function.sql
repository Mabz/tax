-- Fix get_admin_authorities function for country admins
-- The issue is in the WHERE clause - it should check authority_id not country_id

DROP FUNCTION IF EXISTS get_admin_authorities();

CREATE OR REPLACE FUNCTION get_admin_authorities()
RETURNS TABLE (
  id uuid,
  country_id uuid,
  name text,
  code text,
  authority_type text,
  description text,
  is_active boolean,
  pass_advance_days integer,
  default_currency_code text,
  created_at timestamptz,
  updated_at timestamptz,
  country_name text,
  country_code text
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    a.id,
    a.country_id,
    a.name,
    a.code,
    a.authority_type,
    a.description,
    a.is_active,
    a.pass_advance_days,
    a.default_currency_code,
    a.created_at,
    a.updated_at,
    c.name as country_name,
    c.country_code
  FROM authorities a
  JOIN countries c ON c.id = a.country_id
  WHERE 
    a.is_active = true
    AND (
      -- Superusers can see all authorities
      is_superuser()
      OR
      -- Country admins can see authorities they are assigned to
      (
        user_has_role('country_admin') AND
        a.id IN (
          SELECT DISTINCT pr.authority_id
          FROM profile_roles pr
          JOIN roles r ON r.id = pr.role_id
          WHERE pr.profile_id = auth.uid()
          AND r.name = 'country_admin'
          AND pr.is_active = true
        )
      )
      OR
      -- Country auditors can see authorities they are assigned to
      (
        user_has_role('country_auditor') AND
        a.id IN (
          SELECT DISTINCT pr.authority_id
          FROM profile_roles pr
          JOIN roles r ON r.id = pr.role_id
          WHERE pr.profile_id = auth.uid()
          AND r.name = 'country_auditor'
          AND pr.is_active = true
        )
      )
    )
  ORDER BY c.name, a.name;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_admin_authorities() TO authenticated;

-- Test the function
SELECT 
  name,
  code,
  country_name,
  authority_type
FROM get_admin_authorities()
ORDER BY country_name, name;