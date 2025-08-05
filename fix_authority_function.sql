-- Fix the get_authority_by_id function to use correct profile_roles table structure
-- This replaces the non-existent role_assignments table with proper authority_id checks

CREATE OR REPLACE FUNCTION get_authority_by_id(target_authority_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Check if user has permission to view this authority
    IF NOT (
        -- Superuser can view any authority
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name = 'superuser'
            AND pr.is_active = true
        )
        OR
        -- Country admin can view authorities they are assigned to
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND pr.authority_id = target_authority_id
            AND r.name = 'country_admin'
            AND pr.is_active = true
        )
        OR
        -- Country auditor can view authorities they are assigned to
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND pr.authority_id = target_authority_id
            AND r.name = 'country_auditor'
            AND pr.is_active = true
        )
    ) THEN
        RAISE EXCEPTION 'Access denied: insufficient permissions to view authority';
    END IF;

    -- Fetch authority details with country information
    SELECT json_build_object(
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
    INTO result
    FROM authorities a
    JOIN countries c ON a.country_id = c.id
    WHERE a.id = target_authority_id;

    IF result IS NULL THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    RETURN result;
END;
$$;
