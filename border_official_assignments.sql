-- Border Official Assignment System
-- This migration adds support for assigning border officials to specific borders

-- Note: border_official_borders table already exists in the schema
-- This file provides functions to work with the existing table

-- Add indexes for performance if they don't exist
CREATE INDEX IF NOT EXISTS idx_border_official_borders_profile_id ON border_official_borders(profile_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_border_id ON border_official_borders(border_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_active ON border_official_borders(is_active);

-- Add RLS policies if not already enabled
ALTER TABLE border_official_borders ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view assignments for their authority's borders
CREATE POLICY "Users can view border assignments for their authority" ON border_official_borders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM borders b
            JOIN authorities a ON b.authority_id = a.id
            JOIN profile_roles pr ON pr.authority_id = a.id
            WHERE b.id = border_official_borders.border_id
            AND pr.profile_id = auth.uid()
            AND pr.is_active = true
        )
    );

-- Policy: Country admins and superusers can manage assignments
CREATE POLICY "Admins can manage border assignments" ON border_official_borders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM borders b
            JOIN authorities a ON b.authority_id = a.id
            JOIN profile_roles pr ON pr.authority_id = a.id
            JOIN roles r ON pr.role_id = r.id
            WHERE b.id = border_official_borders.border_id
            AND pr.profile_id = auth.uid()
            AND pr.is_active = true
            AND r.name IN ('country_admin', 'superuser')
        )
    );

-- Function to assign a border official to a border
CREATE OR REPLACE FUNCTION assign_official_to_border(
    target_profile_id UUID,
    target_border_id UUID,
    assignment_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    assignment_id UUID;
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    -- Check if current user has permission to make assignments
    IF NOT EXISTS (
        SELECT 1 FROM borders b
        JOIN authorities a ON b.authority_id = a.id
        JOIN profile_roles pr ON pr.authority_id = a.id
        JOIN roles r ON pr.role_id = r.id
        WHERE b.id = target_border_id
        AND pr.profile_id = current_user_id
        AND pr.is_active = true
        AND r.name IN ('country_admin', 'superuser')
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to assign border officials';
    END IF;
    
    -- Check if target profile is a border official in the same authority
    IF NOT EXISTS (
        SELECT 1 FROM borders b
        JOIN authorities a ON b.authority_id = a.id
        JOIN profile_roles pr ON pr.authority_id = a.id
        JOIN roles r ON pr.role_id = r.id
        WHERE b.id = target_border_id
        AND pr.profile_id = target_profile_id
        AND pr.is_active = true
        AND r.name = 'border_official'
    ) THEN
        RAISE EXCEPTION 'Target profile is not a border official in the required authority';
    END IF;
    
    -- Deactivate any existing assignment for this profile-border combination
    UPDATE border_official_borders 
    SET is_active = false, updated_at = NOW()
    WHERE profile_id = target_profile_id 
    AND border_id = target_border_id 
    AND is_active = true;
    
    -- Create new assignment
    INSERT INTO border_official_borders (
        profile_id, 
        border_id, 
        assigned_by_profile_id, 
        is_active
    ) VALUES (
        target_profile_id, 
        target_border_id, 
        current_user_id, 
        true
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$;

-- Function to revoke a border official's assignment from a border
CREATE OR REPLACE FUNCTION revoke_official_from_border(
    target_profile_id UUID,
    target_border_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    -- Check if current user has permission to revoke assignments
    IF NOT EXISTS (
        SELECT 1 FROM borders b
        JOIN authorities a ON b.authority_id = a.id
        JOIN profile_roles pr ON pr.authority_id = a.id
        JOIN roles r ON pr.role_id = r.id
        WHERE b.id = target_border_id
        AND pr.profile_id = current_user_id
        AND pr.is_active = true
        AND r.name IN ('country_admin', 'superuser')
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to revoke border assignments';
    END IF;
    
    -- Deactivate the assignment
    UPDATE border_official_borders 
    SET is_active = false, updated_at = NOW()
    WHERE profile_id = target_profile_id 
    AND border_id = target_border_id 
    AND is_active = true;
    
    RETURN FOUND;
END;
$$;

-- Function to get assigned borders for a country or current user
CREATE OR REPLACE FUNCTION get_assigned_borders(
    target_country_id UUID DEFAULT NULL
)
RETURNS TABLE (
    border_id UUID,
    border_name TEXT,
    border_type_label TEXT,
    country_name TEXT,
    official_profile_id UUID,
    official_name TEXT,
    official_email TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    
    RETURN QUERY
    SELECT 
        ba.border_id,
        b.name as border_name,
        bt.label as border_type_label,
        c.name as country_name,
        ba.profile_id as official_profile_id,
        p.full_name as official_name,
        p.email as official_email,
        ba.assigned_at
    FROM border_official_borders ba
    JOIN borders b ON ba.border_id = b.id
    JOIN border_types bt ON b.border_type_id = bt.id
    JOIN authorities a ON b.authority_id = a.id
    JOIN countries c ON a.country_id = c.id
    JOIN profiles p ON ba.profile_id = p.id
    WHERE ba.is_active = true
    AND (target_country_id IS NULL OR a.country_id = target_country_id)
    AND EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = current_user_id
        AND pr.authority_id = a.id
        AND pr.is_active = true
        AND r.name IN ('country_admin', 'superuser', 'border_official')
    )
    ORDER BY c.name, b.name, p.full_name;
END;
$$;

-- Function to get border officials for a country with their assignments
CREATE OR REPLACE FUNCTION get_border_officials_for_country(
    target_country_id UUID
)
RETURNS TABLE (
    profile_id UUID,
    full_name TEXT,
    email TEXT,
    border_count BIGINT,
    assigned_borders TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as profile_id,
        p.full_name,
        p.email,
        COUNT(ba.border_id) as border_count,
        STRING_AGG(b.name, ', ' ORDER BY b.name) as assigned_borders
    FROM profiles p
    JOIN profile_roles pr ON p.id = pr.profile_id
    JOIN roles r ON pr.role_id = r.id
    JOIN authorities a ON pr.authority_id = a.id
    LEFT JOIN border_official_borders ba ON p.id = ba.profile_id AND ba.is_active = true
    LEFT JOIN borders b ON ba.border_id = b.id
    WHERE a.country_id = target_country_id
    AND r.name = 'border_official'
    AND pr.is_active = true
    AND EXISTS (
        SELECT 1 FROM profile_roles pr2
        JOIN roles r2 ON pr2.role_id = r2.id
        JOIN authorities a2 ON pr2.authority_id = a2.id
        WHERE pr2.profile_id = auth.uid()
        AND a2.country_id = target_country_id
        AND pr2.is_active = true
        AND r2.name IN ('country_admin', 'superuser')
    )
    GROUP BY p.id, p.full_name, p.email
    ORDER BY p.full_name;
END;
$$;

-- Function to get unassigned borders for a country
CREATE OR REPLACE FUNCTION get_unassigned_borders_for_country(
    target_country_id UUID
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    border_type_id UUID,
    authority_id UUID,
    is_active BOOLEAN,
    latitude DECIMAL,
    longitude DECIMAL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name,
        b.border_type_id,
        b.authority_id,
        b.is_active,
        b.latitude,
        b.longitude,
        b.description,
        b.created_at,
        b.updated_at
    FROM borders b
    JOIN authorities a ON b.authority_id = a.id
    WHERE a.country_id = target_country_id
    AND b.is_active = true
    AND NOT EXISTS (
        SELECT 1 FROM border_official_borders ba
        WHERE ba.border_id = b.id
        AND ba.is_active = true
    )
    AND EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        JOIN authorities a2 ON pr.authority_id = a2.id
        WHERE pr.profile_id = auth.uid()
        AND a2.country_id = target_country_id
        AND pr.is_active = true
        AND r.name IN ('country_admin', 'superuser')
    )
    ORDER BY b.name;
END;
$$;

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON border_official_borders TO authenticated;
GRANT EXECUTE ON FUNCTION assign_official_to_border(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_official_from_border(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_assigned_borders(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_border_officials_for_country(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_unassigned_borders_for_country(UUID) TO authenticated;

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_border_official_borders_updated_at 
    BEFORE UPDATE ON border_official_borders 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();