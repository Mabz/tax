-- Updated pass template functions with separate entry/exit point user selection
-- Run this in Supabase SQL Editor

-- Drop existing functions
DROP FUNCTION IF EXISTS create_pass_template;
DROP FUNCTION IF EXISTS update_pass_template;
DROP FUNCTION IF EXISTS get_pass_templates_for_authority;

-- Create function with separate entry/exit point user selection
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
    allow_user_selectable_entry_point BOOLEAN DEFAULT FALSE,
    allow_user_selectable_exit_point BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_template_id UUID;
    authority_country_id UUID;
BEGIN
    -- Get country_id from authority
    SELECT country_id INTO authority_country_id
    FROM authorities 
    WHERE id = target_authority_id;

    IF authority_country_id IS NULL THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    -- If user selectable entry point is enabled, force entry point to null
    IF allow_user_selectable_entry_point THEN
        target_entry_point_id := NULL;
    END IF;

    -- If user selectable exit point is enabled, force exit point to null
    IF allow_user_selectable_exit_point THEN
        target_exit_point_id := NULL;
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
        allow_user_selectable_entry_point,
        allow_user_selectable_exit_point,
        created_at,
        updated_at
    ) VALUES (
        target_authority_id,
        authority_country_id,
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
        allow_user_selectable_entry_point,
        allow_user_selectable_exit_point,
        NOW(),
        NOW()
    ) RETURNING id INTO new_template_id;

    RETURN new_template_id;
END;
$$;-- U
pdate function with separate entry/exit point user selection
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
    new_allow_user_selectable_entry_point BOOLEAN DEFAULT FALSE,
    new_allow_user_selectable_exit_point BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If user selectable entry point is enabled, force entry point to null
    IF new_allow_user_selectable_entry_point THEN
        new_entry_point_id := NULL;
    END IF;

    -- If user selectable exit point is enabled, force exit point to null
    IF new_allow_user_selectable_exit_point THEN
        new_exit_point_id := NULL;
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
        allow_user_selectable_entry_point = new_allow_user_selectable_entry_point,
        allow_user_selectable_exit_point = new_allow_user_selectable_exit_point,
        updated_at = NOW()
    WHERE id = template_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found';
    END IF;
END;
$$;

-- Get function with separate entry/exit point user selection
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
    allow_user_selectable_entry_point BOOLEAN,
    allow_user_selectable_exit_point BOOLEAN,
    entry_point_id UUID,
    exit_point_id UUID,
    entry_point_name TEXT,
    exit_point_name TEXT,
    vehicle_type TEXT,
    vehicle_type_id UUID,
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
        COALESCE(pt.allow_user_selectable_entry_point, false) as allow_user_selectable_entry_point,
        COALESCE(pt.allow_user_selectable_exit_point, false) as allow_user_selectable_exit_point,
        pt.entry_point_id,
        pt.exit_point_id,
        CASE 
            WHEN pt.entry_point_id IS NULL THEN 'Any Entry Point'
            ELSE COALESCE(entry_border.name, 'Unknown Entry Point')
        END as entry_point_name,
        CASE 
            WHEN pt.exit_point_id IS NULL THEN 'Any Exit Point'
            ELSE COALESCE(exit_border.name, 'Unknown Exit Point')
        END as exit_point_name,
        COALESCE(vt.label, 'Unknown Vehicle Type') as vehicle_type,
        pt.vehicle_type_id,
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
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority TO authenticated;