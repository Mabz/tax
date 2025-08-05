-- Additional Authority Management Cloud Functions
-- These are the missing functions referenced in AuthorityService

-- Function to get all authorities (superuser only)
CREATE OR REPLACE FUNCTION get_all_authorities()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Check if user is superuser
    IF NOT EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        WHERE ur.user_id = auth.uid()
        AND r.name = 'superuser'
    ) THEN
        RAISE EXCEPTION 'Access denied: only superusers can view all authorities';
    END IF;

    -- Get all authorities with country information
    SELECT json_agg(
        json_build_object(
            'id', a.id,
            'country_id', a.country_id,
            'name', a.name,
            'code', a.code,
            'authority_type', a.authority_type,
            'description', a.description,
            'is_active', a.is_active,
            'pass_advance_days', a.pass_advance_days,
            'default_currency_code', a.default_currency_code,
            'created_at', a.created_at,
            'updated_at', a.updated_at,
            'countries', json_build_object(
                'name', c.name,
                'country_code', c.country_code
            )
        )
    )
    INTO result
    FROM authorities a
    JOIN countries c ON a.country_id = c.id
    ORDER BY c.name, a.name;

    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- Function to get authorities for a specific country
CREATE OR REPLACE FUNCTION get_authorities_for_country(target_country_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Check if user has permission to view authorities for this country
    IF NOT (
        -- Superuser can view any country's authorities
        EXISTS (
            SELECT 1 FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid()
            AND r.name = 'superuser'
        )
        OR
        -- Country admin can view authorities in their country
        EXISTS (
            SELECT 1 FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            JOIN role_assignments ra ON ra.role_id = r.id
            WHERE ur.user_id = auth.uid()
            AND r.name = 'country_admin'
            AND ra.country_id = target_country_id
        )
        OR
        -- Country auditor can view authorities in their country
        EXISTS (
            SELECT 1 FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            JOIN role_assignments ra ON ra.role_id = r.id
            WHERE ur.user_id = auth.uid()
            AND r.name = 'country_auditor'
            AND ra.country_id = target_country_id
        )
    ) THEN
        RAISE EXCEPTION 'Access denied: insufficient permissions to view authorities for this country';
    END IF;

    -- Get authorities for the specified country with country information
    SELECT json_agg(
        json_build_object(
            'id', a.id,
            'country_id', a.country_id,
            'name', a.name,
            'code', a.code,
            'authority_type', a.authority_type,
            'description', a.description,
            'is_active', a.is_active,
            'pass_advance_days', a.pass_advance_days,
            'default_currency_code', a.default_currency_code,
            'created_at', a.created_at,
            'updated_at', a.updated_at,
            'countries', json_build_object(
                'name', c.name,
                'country_code', c.country_code
            )
        )
    )
    INTO result
    FROM authorities a
    JOIN countries c ON a.country_id = c.id
    WHERE a.country_id = target_country_id
    ORDER BY a.name;

    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- Function to get authorities that the current user can administer
CREATE OR REPLACE FUNCTION get_admin_authorities()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Get authorities based on user role
    IF EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        WHERE ur.user_id = auth.uid()
        AND r.name = 'superuser'
    ) THEN
        -- Superuser gets all authorities
        SELECT json_agg(
            json_build_object(
                'id', a.id,
                'country_id', a.country_id,
                'name', a.name,
                'code', a.code,
                'authority_type', a.authority_type,
                'description', a.description,
                'is_active', a.is_active,
                'pass_advance_days', a.pass_advance_days,
                'default_currency_code', a.default_currency_code,
                'created_at', a.created_at,
                'updated_at', a.updated_at,
                'countries', json_build_object(
                    'name', c.name,
                    'country_code', c.country_code
                )
            )
        )
        INTO result
        FROM authorities a
        JOIN countries c ON a.country_id = c.id
        ORDER BY c.name, a.name;
    ELSE
        -- Country admin/auditor gets authorities for their assigned countries
        SELECT json_agg(
            json_build_object(
                'id', a.id,
                'country_id', a.country_id,
                'name', a.name,
                'code', a.code,
                'authority_type', a.authority_type,
                'description', a.description,
                'is_active', a.is_active,
                'pass_advance_days', a.pass_advance_days,
                'default_currency_code', a.default_currency_code,
                'created_at', a.created_at,
                'updated_at', a.updated_at,
                'countries', json_build_object(
                    'name', c.name,
                    'country_code', c.country_code
                )
            )
        )
        INTO result
        FROM authorities a
        JOIN countries c ON a.country_id = c.id
        WHERE a.country_id IN (
            SELECT DISTINCT ra.country_id
            FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            JOIN role_assignments ra ON ra.role_id = r.id
            WHERE ur.user_id = auth.uid()
            AND r.name IN ('country_admin', 'country_auditor')
        )
        ORDER BY c.name, a.name;
    END IF;

    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- Function to get all countries (for superuser country selection)
CREATE OR REPLACE FUNCTION get_all_countries()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Check if user is superuser
    IF NOT EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        WHERE ur.user_id = auth.uid()
        AND r.name = 'superuser'
    ) THEN
        RAISE EXCEPTION 'Access denied: only superusers can view all countries';
    END IF;

    -- Get all active countries
    SELECT json_agg(
        json_build_object(
            'id', c.id,
            'name', c.name,
            'country_code', c.country_code,
            'is_active', c.is_active
        )
    )
    INTO result
    FROM countries c
    WHERE c.is_active = true
    ORDER BY c.name;

    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_all_authorities() TO authenticated;
GRANT EXECUTE ON FUNCTION get_authorities_for_country(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_authorities() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_countries() TO authenticated;
