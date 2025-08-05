-- Authority Management Cloud Functions
-- These functions handle CRUD operations for authorities with proper RLS

-- Function to get authority by ID
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

    -- Get authority with country information
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

-- Function to create authority (superuser only)
CREATE OR REPLACE FUNCTION create_authority(
    target_country_id UUID,
    authority_name TEXT,
    authority_code TEXT,
    authority_type TEXT,
    authority_description TEXT DEFAULT NULL,
    authority_pass_advance_days INTEGER DEFAULT 30,
    authority_default_currency_code TEXT DEFAULT NULL,
    authority_is_active BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_authority_id UUID;
BEGIN
    -- Check if user is superuser
    IF NOT EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'superuser'
    ) THEN
        RAISE EXCEPTION 'Access denied: only superusers can create authorities';
    END IF;

    -- Validate country exists
    IF NOT EXISTS (SELECT 1 FROM countries WHERE id = target_country_id) THEN
        RAISE EXCEPTION 'Country not found';
    END IF;

    -- Check if authority code already exists for this country
    IF EXISTS (
        SELECT 1 FROM authorities 
        WHERE country_id = target_country_id 
        AND UPPER(code) = UPPER(authority_code)
    ) THEN
        RAISE EXCEPTION 'Authority code already exists for this country';
    END IF;

    -- Validate authority type
    IF authority_type NOT IN ('revenue_service', 'customs', 'immigration', 'global') THEN
        RAISE EXCEPTION 'Invalid authority type';
    END IF;

    -- Create the authority
    INSERT INTO authorities (
        country_id,
        name,
        code,
        authority_type,
        description,
        is_active,
        pass_advance_days,
        default_currency_code,
        created_at,
        updated_at
    ) VALUES (
        target_country_id,
        authority_name,
        UPPER(authority_code),
        authority_type,
        authority_description,
        authority_is_active,
        authority_pass_advance_days,
        authority_default_currency_code,
        NOW(),
        NOW()
    ) RETURNING id INTO new_authority_id;

    RETURN new_authority_id;
END;
$$;

-- Function to update authority
CREATE OR REPLACE FUNCTION update_authority(
    target_authority_id UUID,
    new_name TEXT,
    new_code TEXT,
    new_authority_type TEXT,
    new_description TEXT DEFAULT NULL,
    new_pass_advance_days INTEGER DEFAULT 30,
    new_default_currency_code TEXT DEFAULT NULL,
    new_is_active BOOLEAN DEFAULT TRUE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    authority_country_id UUID;
    is_superuser BOOLEAN := FALSE;
    is_country_admin BOOLEAN := FALSE;
BEGIN
    -- Get authority's country
    SELECT country_id INTO authority_country_id
    FROM authorities
    WHERE id = target_authority_id;

    IF authority_country_id IS NULL THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    -- Check user permissions
    SELECT EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'superuser'
    ) INTO is_superuser;

    SELECT EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        JOIN role_assignments ra ON ra.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'country_admin'
        AND ra.country_id = authority_country_id
    ) INTO is_country_admin;

    IF NOT (is_superuser OR is_country_admin) THEN
        RAISE EXCEPTION 'Access denied: insufficient permissions to update authority';
    END IF;

    -- Check if authority code already exists for this country (excluding current authority)
    IF EXISTS (
        SELECT 1 FROM authorities 
        WHERE country_id = authority_country_id 
        AND UPPER(code) = UPPER(new_code)
        AND id != target_authority_id
    ) THEN
        RAISE EXCEPTION 'Authority code already exists for this country';
    END IF;

    -- Validate authority type
    IF new_authority_type NOT IN ('revenue_service', 'customs', 'immigration', 'global') THEN
        RAISE EXCEPTION 'Invalid authority type';
    END IF;

    -- Country admins cannot change active status - only superusers can
    IF is_country_admin AND NOT is_superuser THEN
        -- Update without changing is_active
        UPDATE authorities SET
            name = new_name,
            code = UPPER(new_code),
            authority_type = new_authority_type,
            description = new_description,
            pass_advance_days = new_pass_advance_days,
            default_currency_code = new_default_currency_code,
            updated_at = NOW()
        WHERE id = target_authority_id;
    ELSE
        -- Superuser can update everything including is_active
        UPDATE authorities SET
            name = new_name,
            code = UPPER(new_code),
            authority_type = new_authority_type,
            description = new_description,
            is_active = new_is_active,
            pass_advance_days = new_pass_advance_days,
            default_currency_code = new_default_currency_code,
            updated_at = NOW()
        WHERE id = target_authority_id;
    END IF;
END;
$$;

-- Function to delete authority (superuser only)
CREATE OR REPLACE FUNCTION delete_authority(target_authority_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is superuser
    IF NOT EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = auth.uid()
        AND r.name = 'superuser'
    ) THEN
        RAISE EXCEPTION 'Access denied: only superusers can delete authorities';
    END IF;

    -- Check if authority exists
    IF NOT EXISTS (SELECT 1 FROM authorities WHERE id = target_authority_id) THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    -- Check if authority has any passes issued
    IF EXISTS (SELECT 1 FROM purchased_passes WHERE authority_id = target_authority_id) THEN
        RAISE EXCEPTION 'Cannot delete authority with issued passes. Set to inactive instead.';
    END IF;

    -- Check if authority has any pass templates
    IF EXISTS (SELECT 1 FROM pass_templates WHERE authority_id = target_authority_id) THEN
        RAISE EXCEPTION 'Cannot delete authority with pass templates. Set to inactive instead.';
    END IF;

    -- Soft delete by setting inactive
    UPDATE authorities SET
        is_active = FALSE,
        updated_at = NOW()
    WHERE id = target_authority_id;
END;
$$;

-- Function to check if authority code exists
CREATE OR REPLACE FUNCTION authority_code_exists(
    target_country_id UUID,
    target_code TEXT,
    exclude_authority_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM authorities
        WHERE country_id = target_country_id
        AND UPPER(code) = UPPER(target_code)
        AND (exclude_authority_id IS NULL OR id != exclude_authority_id)
    );
END;
$$;

-- Function to get authority statistics
CREATE OR REPLACE FUNCTION get_authority_stats(target_authority_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    authority_country_id UUID;
BEGIN
    -- Get authority's country
    SELECT country_id INTO authority_country_id
    FROM authorities
    WHERE id = target_authority_id;

    IF authority_country_id IS NULL THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    -- Check if user has permission to view this authority
    IF NOT (
        -- Superuser can view any authority
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name = 'superuser'
        )
        OR
        -- Country admin/auditor can view authorities in their country
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            JOIN role_assignments ra ON ra.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name IN ('country_admin', 'country_auditor')
            AND ra.country_id = authority_country_id
        )
    ) THEN
        RAISE EXCEPTION 'Access denied: insufficient permissions to view authority statistics';
    END IF;

    -- Get statistics
    SELECT json_build_object(
        'total_passes_issued', COALESCE(
            (SELECT COUNT(*) FROM purchased_passes WHERE authority_id = target_authority_id), 0
        ),
        'active_passes', COALESCE(
            (SELECT COUNT(*) FROM purchased_passes 
             WHERE authority_id = target_authority_id 
             AND status = 'active' 
             AND expires_at > NOW()), 0
        ),
        'total_revenue', COALESCE(
            (SELECT SUM(amount) FROM purchased_passes WHERE authority_id = target_authority_id), 0
        ),
        'pass_templates_count', COALESCE(
            (SELECT COUNT(*) FROM pass_templates WHERE authority_id = target_authority_id), 0
        ),
        'borders_count', COALESCE(
            (SELECT COUNT(DISTINCT b.id) FROM borders b
             JOIN countries c ON b.country_id = c.id
             WHERE c.id = authority_country_id), 0
        )
    ) INTO result;

    RETURN result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_authority_by_id(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_authority(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION update_authority(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_authority(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION authority_code_exists(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_authority_stats(UUID) TO authenticated;
