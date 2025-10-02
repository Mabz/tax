-- Clean solution: Recreate pass_templates table without problematic foreign keys
-- This is safe for development since you mentioned we can drop the table

BEGIN;

-- Drop the existing pass_templates table and recreate it
DROP TABLE IF EXISTS pass_templates CASCADE;

-- Recreate pass_templates table with proper structure but relaxed constraints for development
CREATE TABLE pass_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    authority_id UUID NOT NULL REFERENCES authorities(id),
    country_id UUID NOT NULL REFERENCES countries(id),
    entry_point_id UUID REFERENCES borders(id),
    exit_point_id UUID REFERENCES borders(id),
    vehicle_type_id UUID NOT NULL REFERENCES vehicle_types(id),
    description TEXT NOT NULL,
    entry_limit INTEGER NOT NULL DEFAULT 1,
    expiration_days INTEGER NOT NULL DEFAULT 30,
    pass_advance_days INTEGER NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    currency_code TEXT NOT NULL DEFAULT 'USD',
    allow_user_selectable_points BOOLEAN DEFAULT FALSE,
    created_by_profile_id UUID NOT NULL, -- No foreign key constraint for development
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_pass_templates_authority_id ON pass_templates(authority_id);
CREATE INDEX idx_pass_templates_entry_point_id ON pass_templates(entry_point_id);
CREATE INDEX idx_pass_templates_exit_point_id ON pass_templates(exit_point_id);
CREATE INDEX idx_pass_templates_vehicle_type_id ON pass_templates(vehicle_type_id);
CREATE INDEX idx_pass_templates_active ON pass_templates(is_active);

-- Enable RLS (optional, can be disabled for development)
-- ALTER TABLE pass_templates ENABLE ROW LEVEL SECURITY;

-- Create simple function without permission checks (for development)
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

-- Create update function
CREATE OR REPLACE FUNCTION update_pass_template(
    template_id UUID,
    new_description TEXT,
    new_entry_limit INTEGER,
    new_expiration_days INTEGER,
    new_pass_advance_days INTEGER,
    new_tax_amount DECIMAL,
    new_currency_code TEXT,
    new_is_active BOOLEAN,
    new_entry_point_id UUID DEFAULT NULL,
    new_exit_point_id UUID DEFAULT NULL,
    new_allow_user_selectable_points BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Simple update without complex permission checks
    UPDATE pass_templates
    SET 
        description = new_description,
        entry_limit = new_entry_limit,
        expiration_days = new_expiration_days,
        pass_advance_days = new_pass_advance_days,
        tax_amount = new_tax_amount,
        currency_code = new_currency_code,
        is_active = new_is_active,
        entry_point_id = new_entry_point_id,
        exit_point_id = new_exit_point_id,
        allow_user_selectable_points = new_allow_user_selectable_points,
        updated_at = NOW()
    WHERE id = template_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found: %', template_id;
    END IF;
END;
$$;

-- Create get function
CREATE OR REPLACE FUNCTION get_pass_templates_for_authority(target_authority_id UUID)
RETURNS TABLE (
    id UUID,
    description TEXT,
    entry_limit INTEGER,
    expiration_days INTEGER,
    pass_advance_days INTEGER,
    tax_amount DECIMAL,
    currency_code TEXT,
    is_active BOOLEAN,
    allow_user_selectable_points BOOLEAN,
    entry_point_name TEXT,
    exit_point_name TEXT,
    vehicle_type TEXT
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
        pt.currency_code,
        pt.is_active,
        pt.allow_user_selectable_points,
        entry_border.name AS entry_point_name,
        exit_border.name AS exit_point_name,
        vt.label AS vehicle_type
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

-- Test the function
SELECT create_pass_template(
    '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615'::UUID,
    'f029133e-39cf-4ac4-a04e-25f7b59ef604'::UUID,
    '02d4b3f7-b784-4c40-8078-4f0ad36d1590'::UUID,
    'Test Bus Pass',
    1, 30, 30, 0.00, 'GBP',
    NULL, NULL, FALSE
) as test_result;

RAISE NOTICE 'Pass templates table recreated and function working!';

COMMIT;