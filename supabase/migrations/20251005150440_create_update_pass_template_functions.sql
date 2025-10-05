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
    has_is_active_column BOOLEAN;
    has_allow_user_selectable_points_column BOOLEAN;
    has_pass_advance_days_column BOOLEAN;
BEGIN
    -- Check which columns exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'is_active'
    ) INTO has_is_active_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) INTO has_allow_user_selectable_points_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'pass_advance_days'
    ) INTO has_pass_advance_days_column;

    -- Validate that the authority exists
    IF NOT EXISTS (
        SELECT 1 FROM authorities 
        WHERE id = target_authority_id
    ) THEN
        RAISE EXCEPTION 'Authority not found';
    END IF;

    -- Validate vehicle type exists
    IF NOT EXISTS (
        SELECT 1 FROM vehicle_types 
        WHERE id = vehicle_type_id
    ) THEN
        RAISE EXCEPTION 'Vehicle type not found';
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
        ) THEN
            RAISE EXCEPTION 'Exit point not found or not associated with this authority';
        END IF;
    END IF;

    -- Insert the new pass template with dynamic column handling
    IF has_is_active_column AND has_allow_user_selectable_points_column AND has_pass_advance_days_column THEN
        -- All columns exist
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
            true,
            allow_user_selectable_points,
            NOW(),
            NOW()
        FROM authorities a
        WHERE a.id = target_authority_id
        RETURNING id INTO new_template_id;
    ELSE
        -- Fallback for missing columns - insert only core columns
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
            tax_amount,
            currency_code,
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
            tax_amount,
            currency_code,
            NOW(),
            NOW()
        FROM authorities a
        WHERE a.id = target_authority_id
        RETURNING id INTO new_template_id;
    END IF;

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
    has_is_active_column BOOLEAN;
    has_allow_user_selectable_points_column BOOLEAN;
    has_pass_advance_days_column BOOLEAN;
BEGIN
    -- Check which columns exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'is_active'
    ) INTO has_is_active_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) INTO has_allow_user_selectable_points_column;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'pass_advance_days'
    ) INTO has_pass_advance_days_column;

    -- Get the template's authority ID for validation
    SELECT authority_id INTO template_authority_id
    FROM pass_templates
    WHERE id = template_id;

    IF template_authority_id IS NULL THEN
        RAISE EXCEPTION 'Pass template not found';
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
        ) THEN
            RAISE EXCEPTION 'Exit point not found or not associated with this authority';
        END IF;
    END IF;

    -- Update the pass template with dynamic column handling
    IF has_is_active_column AND has_allow_user_selectable_points_column AND has_pass_advance_days_column THEN
        -- All columns exist
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
    ELSE
        -- Fallback for missing columns - update only core columns
        UPDATE pass_templates
        SET 
            description = new_description,
            entry_limit = new_entry_limit,
            expiration_days = new_expiration_days,
            tax_amount = new_tax_amount,
            currency_code = new_currency_code,
            vehicle_type_id = COALESCE(new_vehicle_type_id, vehicle_type_id),
            entry_point_id = new_entry_point_id,
            exit_point_id = new_exit_point_id,
            updated_at = NOW()
        WHERE id = template_id;
    END IF;

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
DECLARE
    has_is_active_column BOOLEAN;
BEGIN
    -- Check if is_active column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'is_active'
    ) INTO has_is_active_column;

    -- Check if template has any purchased passes
    IF EXISTS (
        SELECT 1 FROM purchased_passes 
        WHERE pass_template_id = template_id
    ) THEN
        -- Soft delete if there are purchased passes and is_active column exists
        IF has_is_active_column THEN
            UPDATE pass_templates
            SET is_active = false, updated_at = NOW()
            WHERE id = template_id;
        ELSE
            -- Cannot delete if purchased passes exist and no soft delete column
            RAISE EXCEPTION 'Cannot delete template with existing purchased passes';
        END IF;
        
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION delete_pass_template TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pass_templates_authority_id ON pass_templates(authority_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_vehicle_type_id ON pass_templates(vehicle_type_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_entry_point_id ON pass_templates(entry_point_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_exit_point_id ON pass_templates(exit_point_id);