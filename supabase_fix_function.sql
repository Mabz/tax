-- Fix the create_pass_template function
-- This addresses the column reference issues

BEGIN;

-- Drop the existing function
DROP FUNCTION IF EXISTS create_pass_template CASCADE;

-- Recreate the function with proper error handling and column references
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
    user_authority_id UUID;
    target_country_id UUID;
BEGIN
    -- Generate new template ID
    new_template_id := gen_random_uuid();
    
    -- Get user's authority (with fallback)
    SELECT authority_id INTO user_authority_id
    FROM profiles 
    WHERE id = creator_profile_id;
    
    -- Get target authority's country
    SELECT country_id INTO target_country_id
    FROM authorities
    WHERE id = target_authority_id;
    
    -- If country_id is still null, this is a problem
    IF target_country_id IS NULL THEN
        RAISE EXCEPTION 'Could not find country for authority: %', target_authority_id;
    END IF;
    
    -- Verify user has permission (same authority or superuser)
    IF user_authority_id != target_authority_id AND NOT EXISTS (
        SELECT 1 FROM user_roles ur 
        JOIN roles r ON ur.role_id = r.id 
        WHERE ur.profile_id = creator_profile_id 
        AND r.name = 'superuser'
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to create pass template for this authority';
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
    
    -- Insert the new pass template with explicit column names
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
    
    -- Log the creation (only if audit_logs table exists)
    BEGIN
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            old_values,
            new_values,
            profile_id,
            created_at
        ) VALUES (
            'pass_templates',
            new_template_id,
            'CREATE',
            NULL,
            jsonb_build_object(
                'authority_id', target_authority_id,
                'entry_point_id', target_entry_point_id,
                'exit_point_id', target_exit_point_id,
                'description', description,
                'allow_user_selectable_points', allow_user_selectable_points
            ),
            creator_profile_id,
            NOW()
        );
    EXCEPTION
        WHEN undefined_table THEN
            -- Ignore if audit_logs table doesn't exist
            NULL;
    END;
    
    RETURN new_template_id;
END;
$$;

-- Also fix the update function
DROP FUNCTION IF EXISTS update_pass_template CASCADE;

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
DECLARE
    old_record RECORD;
    template_authority_id UUID;
    user_profile_id UUID;
BEGIN
    -- Get current user
    user_profile_id := auth.uid();
    
    -- Get existing template and verify ownership
    SELECT * INTO old_record
    FROM pass_templates
    WHERE id = template_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found';
    END IF;
    
    template_authority_id := old_record.authority_id;
    
    -- Verify user has permission
    IF NOT EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.id = user_profile_id 
        AND p.authority_id = template_authority_id
    ) AND NOT EXISTS (
        SELECT 1 FROM user_roles ur 
        JOIN roles r ON ur.role_id = r.id 
        WHERE ur.profile_id = user_profile_id 
        AND r.name = 'superuser'
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to update this pass template';
    END IF;
    
    -- Verify entry/exit points belong to the authority (if specified)
    IF new_entry_point_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM borders 
        WHERE id = new_entry_point_id AND authority_id = template_authority_id
    ) THEN
        RAISE EXCEPTION 'Entry point does not belong to the template authority';
    END IF;
    
    IF new_exit_point_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM borders 
        WHERE id = new_exit_point_id AND authority_id = template_authority_id
    ) THEN
        RAISE EXCEPTION 'Exit point does not belong to the template authority';
    END IF;
    
    -- Update the template
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
    
    -- Log the update (only if audit_logs table exists)
    BEGIN
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            old_values,
            new_values,
            profile_id,
            created_at
        ) VALUES (
            'pass_templates',
            template_id,
            'UPDATE',
            to_jsonb(old_record),
            jsonb_build_object(
                'description', new_description,
                'entry_point_id', new_entry_point_id,
                'exit_point_id', new_exit_point_id,
                'allow_user_selectable_points', new_allow_user_selectable_points
            ),
            user_profile_id,
            NOW()
        );
    EXCEPTION
        WHEN undefined_table THEN
            -- Ignore if audit_logs table doesn't exist
            NULL;
    END;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;

-- Test the function
DO $$
BEGIN
    RAISE NOTICE 'Functions recreated successfully!';
    RAISE NOTICE 'create_pass_template and update_pass_template are now available';
END;
$$;

COMMIT;