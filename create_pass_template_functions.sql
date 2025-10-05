-- Create functions for pass template management

-- Function to create a new pass template
CREATE OR REPLACE FUNCTION create_pass_template(
    target_authority_id UUID,
    creator_profile_id UUID,
    vehicle_type_id UUID,
    description TEXT,
    entry_limit INTEGER,
    expiration_days INTEGER,
    pass_advance_days INTEGER,
    tax_amount DECIMAL(10,2),
    currency_code VARCHAR(3),
    target_entry_point_id UUID DEFAULT NULL,
    target_exit_point_id UUID DEFAULT NULL,
    allow_user_selectable_points BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_template_id UUID;
BEGIN
    -- Validate that the authority exists and user has permission
    IF NOT EXISTS (
        SELECT 1 FROM authorities 
        WHERE id = target_authority_id 
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Authority not found or inactive';
    END IF;

    -- Validate vehicle type exists
    IF NOT EXISTS (
        SELECT 1 FROM vehicle_types 
        WHERE id = vehicle_type_id 
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Vehicle type not found or inactive';
    END IF;

    -- Validate currency exists
    IF NOT EXISTS (
        SELECT 1 FROM currencies 
        WHERE code = currency_code 
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Currency not found or inactive';
    END IF;

    -- If user selectable points is enabled, force entry/exit points to null
    IF allow_user_selectable_points THEN
        target_entry_point_id := NULL;
        target_exit_point_id := NULL;
    END IF;

    -- Validate entry point if specified
    IF target_entry_point_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM borders 
            WHERE id = target_entry_point_id 
            AND authority_id = target_authority_id
            AND is_active = true
        ) THEN
            RAISE EXCEPTION 'Entry point not found or not associated with this authority';
        END IF;
    END IF;

    -- Validate exit point if specified
    IF target_exit_point_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM borders 
            WHERE id = target_exit_point_id 
            AND authority_id = target_authority_id
            AND is_active = true
        ) THEN
            RAISE EXCEPTION 'Exit point not found or not associated with this authority';
        END IF;
    END IF;

    -- Insert the new pass template
    INSERT INTO pass_templates (
        authority_id,
        country_id,
        entry_point_id,
        exit_point_id,
        created_by_profile_id,
        vehicle_type_id,
        description,
        entry_limit,
        expiration_days,
        pass_advance_days,
        tax_amount,
        currency_code,
        is_active,
        allow_user_selectable_points,
        created_at,
        updated_at
    )
    SELECT 
        target_authority_id,
        a.country_id,
        target_entry_point_id,
        target_exit_point_id,
        creator_profile_id,
        vehicle_type_id,
        description,
        entry_limit,
        expiration_days,
        pass_advance_days,
        tax_amount,
        currency_code,
        true, -- is_active defaults to true for new templates
        allow_user_selectable_points,
        NOW(),
        NOW()
    FROM authorities a
    WHERE a.id = target_authority_id
    RETURNING id INTO new_template_id;

    RETURN new_template_id;
END;
$$;

-- Function to update an existing pass template
CREATE OR REPLACE FUNCTION update_pass_template(
    template_id UUID,
    new_description TEXT,
    new_entry_limit INTEGER,
    new_expiration_days INTEGER,
    new_pass_advance_days INTEGER,
    new_tax_amount DECIMAL(10,2),
    new_currency_code VARCHAR(3),
    new_is_active BOOLEAN,
    new_vehicle_type_id UUID DEFAULT NULL,
    new_entry_point_id UUID DEFAULT NULL,
    new_exit_point_id UUID DEFAULT NULL,
    new_allow_user_selectable_points BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    template_authority_id UUID;
BEGIN
    -- Get the template's authority ID for validation
    SELECT authority_id INTO template_authority_id
    FROM pass_templates
    WHERE id = template_id;

    IF template_authority_id IS NULL THEN
        RAISE EXCEPTION 'Pass template not found';
    END IF;

    -- Validate currency exists
    IF NOT EXISTS (
        SELECT 1 FROM currencies 
        WHERE code = new_currency_code 
        AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Currency not found or inactive';
    END IF;

    -- Validate vehicle type if provided
    IF new_vehicle_type_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM vehicle_types 
            WHERE id = new_vehicle_type_id 
            AND is_active = true
        ) THEN
            RAISE EXCEPTION 'Vehicle type not found or inactive';
        END IF;
    END IF;

    -- If user selectable points is enabled, force entry/exit points to null
    IF new_allow_user_selectable_points THEN
        new_entry_point_id := NULL;
        new_exit_point_id := NULL;
    END IF;

    -- Validate entry point if specified
    IF new_entry_point_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM borders 
            WHERE id = new_entry_point_id 
            AND authority_id = template_authority_id
            AND is_active = true
        ) THEN
            RAISE EXCEPTION 'Entry point not found or not associated with this authority';
        END IF;
    END IF;

    -- Validate exit point if specified
    IF new_exit_point_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM borders 
            WHERE id = new_exit_point_id 
            AND authority_id = template_authority_id
            AND is_active = true
        ) THEN
            RAISE EXCEPTION 'Exit point not found or not associated with this authority';
        END IF;
    END IF;

    -- Update the pass template
    UPDATE pass_templates
    SET 
        description = new_description,
        entry_limit = new_entry_limit,
        expiration_days = new_expiration_days,
        pass_advance_days = new_pass_advance_days,
        tax_amount = new_tax_amount,
        currency_code = new_currency_code,
        is_active = new_is_active,
        vehicle_type_id = COALESCE(new_vehicle_type_id, vehicle_type_id),
        entry_point_id = new_entry_point_id,
        exit_point_id = new_exit_point_id,
        allow_user_selectable_points = new_allow_user_selectable_points,
        updated_at = NOW()
    WHERE id = template_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found or could not be updated';
    END IF;
END;
$$;

-- Function to delete a pass template (soft delete by setting is_active = false)
CREATE OR REPLACE FUNCTION delete_pass_template(
    template_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if template has any purchased passes
    IF EXISTS (
        SELECT 1 FROM purchased_passes 
        WHERE pass_template_id = template_id
    ) THEN
        -- Soft delete if there are purchased passes
        UPDATE pass_templates
        SET is_active = false, updated_at = NOW()
        WHERE id = template_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Pass template not found';
        END IF;
    ELSE
        -- Hard delete if no purchased passes exist
        DELETE FROM pass_templates
        WHERE id = template_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Pass template not found';
        END IF;
    END IF;
END;
$$;

-- Function to get pass templates for an authority with all related data
CREATE OR REPLACE FUNCTION get_pass_templates_for_authority(
    target_authority_id UUID
)
RETURNS TABLE (
    id UUID,
    description TEXT,
    entry_limit INTEGER,
    expiration_days INTEGER,
    pass_advance_days INTEGER,
    tax_amount NUMERIC,
    currency_code TEXT,
    is_active BOOLEAN,
    allow_user_selectable_points BOOLEAN,
    entry_point_id UUID,
    exit_point_id UUID,
    entry_point_name TEXT,
    exit_point_name TEXT,
    vehicle_type TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.id,
        pt.description,
        pt.entry_limit,
        pt.expiration_days,
        pt.pass_advance_days,
        pt.tax_amount,
        pt.currency_code::TEXT,
        pt.is_active,
        COALESCE(pt.allow_user_selectable_points, false),
        pt.entry_point_id,
        pt.exit_point_id,
        CASE 
            WHEN pt.entry_point_id IS NULL THEN 'Any Entry Point'::TEXT
            ELSE COALESCE(entry_border.name, 'Unknown Entry Point')::TEXT
        END,
        CASE 
            WHEN pt.exit_point_id IS NULL THEN 'Any Exit Point'::TEXT
            ELSE COALESCE(exit_border.name, 'Unknown Exit Point')::TEXT
        END,
        COALESCE(vt.label, 'Unknown Vehicle Type')::TEXT,
        pt.created_at,
        pt.updated_at
    FROM pass_templates pt
    LEFT JOIN borders entry_border ON pt.entry_point_id = entry_border.id
    LEFT JOIN borders exit_border ON pt.exit_point_id = exit_border.id
    LEFT JOIN vehicle_types vt ON pt.vehicle_type_id = vt.id
    WHERE pt.authority_id = target_authority_id
    ORDER BY pt.created_at DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION delete_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pass_templates_authority_id ON pass_templates(authority_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_vehicle_type_id ON pass_templates(vehicle_type_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_entry_point_id ON pass_templates(entry_point_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_exit_point_id ON pass_templates(exit_point_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_is_active ON pass_templates(is_active);