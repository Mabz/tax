-- Manual fix for pass templates - run this in Supabase SQL editor

-- Step 1: Add missing columns if they don't exist
DO $$ 
BEGIN
    -- Add is_active column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN is_active BOOLEAN DEFAULT true NOT NULL;
        RAISE NOTICE 'Added is_active column to pass_templates';
    END IF;

    -- Add allow_user_selectable_points column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' 
        AND column_name = 'allow_user_selectable_points'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN allow_user_selectable_points BOOLEAN DEFAULT false NOT NULL;
        RAISE NOTICE 'Added allow_user_selectable_points column to pass_templates';
    END IF;

    -- Add pass_advance_days column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' 
        AND column_name = 'pass_advance_days'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN pass_advance_days INTEGER DEFAULT 7 NOT NULL;
        RAISE NOTICE 'Added pass_advance_days column to pass_templates';
    END IF;
END $$;

-- Step 2: Fix existing templates with user selectable points
UPDATE pass_templates 
SET 
    entry_point_id = NULL,
    exit_point_id = NULL
WHERE allow_user_selectable_points = true
  AND (entry_point_id IS NOT NULL OR exit_point_id IS NOT NULL);

-- Step 3: Create the simplified create function
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
    -- If user selectable points is enabled, force entry/exit points to null
    IF allow_user_selectable_points THEN
        target_entry_point_id := NULL;
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

    RETURN new_template_id;
END;
$$;

-- Step 4: Create the update function
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

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;

-- Step 6: Show current pass_templates structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pass_templates' 
ORDER BY ordinal_position;