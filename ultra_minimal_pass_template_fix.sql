-- Ultra minimal fix - absolute bare minimum
-- Run this in Supabase SQL Editor

-- Drop existing functions first
DROP FUNCTION IF EXISTS create_pass_template;
DROP FUNCTION IF EXISTS update_pass_template;

-- Create the most basic version possible
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
    authority_country_id UUID;
BEGIN
    -- Get country_id from authority
    SELECT country_id INTO authority_country_id
    FROM authorities 
    WHERE id = target_authority_id;

    IF authority_country_id IS NULL THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    -- If user selectable points is enabled, force entry/exit points to null
    IF allow_user_selectable_points THEN
        target_entry_point_id := NULL;
        target_exit_point_id := NULL;
    END IF;

    -- Try the most basic insert first
    BEGIN
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
            allow_user_selectable_points,
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
            allow_user_selectable_points,
            NOW(),
            NOW()
        ) RETURNING id INTO new_template_id;
    EXCEPTION
        WHEN undefined_column THEN
            -- If that fails, try without country_id
            INSERT INTO pass_templates (
                authority_id,
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
                allow_user_selectable_points,
                created_at,
                updated_at
            ) VALUES (
                target_authority_id,
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
                allow_user_selectable_points,
                NOW(),
                NOW()
            ) RETURNING id INTO new_template_id;
    END;

    RETURN new_template_id;
END;
$$;

-- Basic update function
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
BEGIN
    -- If user selectable points is enabled, force entry/exit points to null
    IF new_allow_user_selectable_points THEN
        new_entry_point_id := NULL;
        new_exit_point_id := NULL;
    END IF;

    -- Basic update
    UPDATE pass_templates
    SET 
        description = new_description,
        entry_limit = new_entry_limit,
        expiration_days = new_expiration_days,
        pass_advance_days = new_pass_advance_days,
        tax_amount = new_tax_amount,
        currency_code = new_currency_code,
        vehicle_type_id = COALESCE(new_vehicle_type_id, vehicle_type_id),
        entry_point_id = new_entry_point_id,
        exit_point_id = new_exit_point_id,
        allow_user_selectable_points = new_allow_user_selectable_points,
        updated_at = NOW()
    WHERE id = template_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found';
    END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;