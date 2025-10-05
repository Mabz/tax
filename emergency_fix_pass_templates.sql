-- Emergency fix - works with existing schema only
-- Run this in Supabase SQL Editor

-- First, let's see what columns actually exist
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_templates' 
ORDER BY ordinal_position;

-- Create a function that works with existing columns only
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
    insert_sql TEXT;
    columns_list TEXT;
    values_list TEXT;
BEGIN
    -- If user selectable points is enabled, force entry/exit points to null
    IF allow_user_selectable_points THEN
        target_entry_point_id := NULL;
        target_exit_point_id := NULL;
    END IF;

    -- Build dynamic insert based on existing columns
    columns_list := 'authority_id, entry_point_id, exit_point_id, created_by_profile_id, vehicle_type_id, description, entry_limit, expiration_days, tax_amount, currency_code, created_at, updated_at';
    values_list := 'target_authority_id, target_entry_point_id, target_exit_point_id, creator_profile_id, vehicle_type_id, description, entry_limit, expiration_days, tax_amount, currency_code, NOW(), NOW()';

    -- Add country_id if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'country_id'
    ) THEN
        columns_list := columns_list || ', country_id';
        values_list := values_list || ', (SELECT country_id FROM authorities WHERE id = target_authority_id)';
    END IF;

    -- Add pass_advance_days if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'pass_advance_days'
    ) THEN
        columns_list := columns_list || ', pass_advance_days';
        values_list := values_list || ', pass_advance_days';
    END IF;

    -- Add is_active if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'is_active'
    ) THEN
        columns_list := columns_list || ', is_active';
        values_list := values_list || ', true';
    END IF;

    -- Add allow_user_selectable_points if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) THEN
        columns_list := columns_list || ', allow_user_selectable_points';
        values_list := values_list || ', allow_user_selectable_points';
    END IF;

    -- Execute dynamic insert
    insert_sql := 'INSERT INTO pass_templates (' || columns_list || ') VALUES (' || values_list || ') RETURNING id';
    
    EXECUTE insert_sql 
    USING target_authority_id, target_entry_point_id, target_exit_point_id, creator_profile_id, 
          vehicle_type_id, description, entry_limit, expiration_days, tax_amount, currency_code, 
          pass_advance_days, allow_user_selectable_points
    INTO new_template_id;

    RETURN new_template_id;
END;
$$;

-- Create update function that works with existing columns
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
    update_sql TEXT;
    set_clause TEXT;
BEGIN
    -- If user selectable points is enabled, force entry/exit points to null
    IF new_allow_user_selectable_points THEN
        new_entry_point_id := NULL;
        new_exit_point_id := NULL;
    END IF;

    -- Build base update clause
    set_clause := 'description = $2, entry_limit = $3, expiration_days = $4, tax_amount = $5, currency_code = $6, entry_point_id = $7, exit_point_id = $8, updated_at = NOW()';

    -- Add vehicle_type_id if provided
    IF new_vehicle_type_id IS NOT NULL THEN
        set_clause := set_clause || ', vehicle_type_id = $9';
    END IF;

    -- Add pass_advance_days if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'pass_advance_days'
    ) THEN
        set_clause := set_clause || ', pass_advance_days = $10';
    END IF;

    -- Add is_active if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'is_active'
    ) THEN
        set_clause := set_clause || ', is_active = $11';
    END IF;

    -- Add allow_user_selectable_points if column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) THEN
        set_clause := set_clause || ', allow_user_selectable_points = $12';
    END IF;

    -- Execute update
    update_sql := 'UPDATE pass_templates SET ' || set_clause || ' WHERE id = $1';
    
    EXECUTE update_sql 
    USING template_id, new_description, new_entry_limit, new_expiration_days, new_tax_amount, 
          new_currency_code, new_entry_point_id, new_exit_point_id, new_vehicle_type_id,
          new_pass_advance_days, new_is_active, new_allow_user_selectable_points;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found or could not be updated';
    END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;