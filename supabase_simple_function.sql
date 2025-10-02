-- Simplified create_pass_template function that works with app-provided authority_id
BEGIN;

DROP FUNCTION IF EXISTS create_pass_template CASCADE;

CREATE OR REPLACE FUNCTION create_pass_template(
    target_authority_id UUID,
    creator_profile_id UUID,
    vehicle_type_id UUID,
    description TEXT,
    entry_limit INTEGER,
    expiration_days INTEGER,
    pass_advance_days INTEGER,
    tax_amount DECIMAL,
    currency_code TEXT,
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
    target_country_id UUID;
BEGIN
    -- Generate new template ID
    new_template_id := gen_random_uuid();
    
    -- Get target authority's country
    SELECT country_id INTO target_country_id
    FROM authorities
    WHERE id = target_authority_id;
    
    -- If country_id is still null, this is a problem
    IF target_country_id IS NULL THEN
        RAISE EXCEPTION 'Could not find country for authority: %', target_authority_id;
    END IF;
    
    -- Verify entry/exit points belong to the authority (if specified)
    IF target_entry_point_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM borders 
        WHERE id = target_entry_point_id AND authority_id = target_authority_id
    ) THEN
        RAISE EXCEPTION 'Entry point does not belong to the specified authority';
    END IF;
    
    IF target_exit_point_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM borders 
        WHERE id = target_exit_point_id AND authority_id = target_authority_id
    ) THEN
        RAISE EXCEPTION 'Exit point does not belong to the specified authority';
    END IF;
    
    -- Insert the new pass template
    INSERT INTO pass_templates (
        id,
        authority_id,
        country_id,
        entry_point_id,
        exit_point_id,
        vehicle_type_id,
        description,
        entry_limit,
        expiration_days,
        pass_advance_days,
        tax_amount,
        currency_code,
        allow_user_selectable_points,
        created_by_profile_id,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        new_template_id,
        target_authority_id,
        target_country_id,
        target_entry_point_id,
        target_exit_point_id,
        vehicle_type_id,
        description,
        entry_limit,
        expiration_days,
        pass_advance_days,
        tax_amount,
        currency_code,
        allow_user_selectable_points,
        creator_profile_id,
        TRUE,
        NOW(),
        NOW()
    );
    
    RETURN new_template_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;

-- Test the function with your data
SELECT create_pass_template(
    '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615'::UUID,  -- target_authority_id (from app dropdown)
    'f029133e-39cf-4ac4-a04e-25f7b59ef604'::UUID,  -- creator_profile_id (current user)
    '02d4b3f7-b784-4c40-8078-4f0ad36d1590'::UUID,  -- vehicle_type_id (Bus)
    'Bus pass any entry/exit points - GBP 0.00 per entry, 1 entries allowed, valid for 30 days, starts in 30 days',
    1,      -- entry_limit
    30,     -- expiration_days
    30,     -- pass_advance_days
    0.00,   -- tax_amount
    'GBP',  -- currency_code
    NULL,   -- target_entry_point_id (any entry point)
    NULL,   -- target_exit_point_id (any exit point)
    FALSE   -- allow_user_selectable_points
) as new_template_id;

COMMIT;