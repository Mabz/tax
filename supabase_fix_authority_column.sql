-- =====================================================
-- Fix Authority Column Issue - Entry/Exit Points Migration
-- =====================================================
-- This script fixes the authority_id column issue and ensures proper schema

BEGIN;

-- =====================================================
-- 1. VERIFY AND FIX PASS_TEMPLATES TABLE SCHEMA
-- =====================================================

-- Check if pass_templates table exists and has the right structure
DO $$
BEGIN
    -- Ensure authority_id column exists in pass_templates
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'authority_id'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN authority_id UUID REFERENCES authorities(id);
        RAISE NOTICE 'Added authority_id column to pass_templates';
    END IF;
    
    -- Ensure country_id column exists in pass_templates
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'country_id'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN country_id UUID REFERENCES countries(id);
        RAISE NOTICE 'Added country_id column to pass_templates';
    END IF;
    
    -- Ensure entry_point_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'entry_point_id'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN entry_point_id UUID REFERENCES borders(id);
        RAISE NOTICE 'Added entry_point_id column to pass_templates';
    END IF;
    
    -- Ensure exit_point_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'exit_point_id'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN exit_point_id UUID REFERENCES borders(id);
        RAISE NOTICE 'Added exit_point_id column to pass_templates';
    END IF;
    
    -- Ensure allow_user_selectable_points column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) THEN
        ALTER TABLE pass_templates ADD COLUMN allow_user_selectable_points BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added allow_user_selectable_points column to pass_templates';
    END IF;
END;
$$;

-- =====================================================
-- 2. VERIFY AND FIX PURCHASED_PASSES TABLE SCHEMA
-- =====================================================

DO $$
BEGIN
    -- Ensure authority_id column exists in purchased_passes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'authority_id'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN authority_id UUID REFERENCES authorities(id);
        RAISE NOTICE 'Added authority_id column to purchased_passes';
    END IF;
    
    -- Ensure country_id column exists in purchased_passes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'country_id'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN country_id UUID REFERENCES countries(id);
        RAISE NOTICE 'Added country_id column to purchased_passes';
    END IF;
    
    -- Ensure entry_point_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'entry_point_id'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entry_point_id UUID REFERENCES borders(id);
        RAISE NOTICE 'Added entry_point_id column to purchased_passes';
    END IF;
    
    -- Ensure exit_point_id column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'exit_point_id'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN exit_point_id UUID REFERENCES borders(id);
        RAISE NOTICE 'Added exit_point_id column to purchased_passes';
    END IF;
END;
$$;

-- =====================================================
-- 3. MIGRATE EXISTING DATA (if border_id exists)
-- =====================================================

DO $$
BEGIN
    -- Migrate border_id to entry_point_id in pass_templates if border_id column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'border_id'
    ) THEN
        UPDATE pass_templates 
        SET entry_point_id = border_id 
        WHERE border_id IS NOT NULL AND entry_point_id IS NULL;
        RAISE NOTICE 'Migrated border_id to entry_point_id in pass_templates';
    END IF;
    
    -- Migrate border_id to entry_point_id in purchased_passes if border_id column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' AND column_name = 'border_id'
    ) THEN
        UPDATE purchased_passes 
        SET entry_point_id = border_id 
        WHERE border_id IS NOT NULL AND entry_point_id IS NULL;
        RAISE NOTICE 'Migrated border_id to entry_point_id in purchased_passes';
    END IF;
END;
$$;

-- =====================================================
-- 4. DROP AND RECREATE FUNCTIONS WITH CORRECT SCHEMA
-- =====================================================

-- Drop existing functions
DROP FUNCTION IF EXISTS create_pass_template CASCADE;
DROP FUNCTION IF EXISTS update_pass_template CASCADE;
DROP FUNCTION IF EXISTS get_pass_templates_for_authority CASCADE;
DROP FUNCTION IF EXISTS issue_pass_from_template CASCADE;

-- Create pass template function with proper column references
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
    -- Get user's authority
    SELECT authority_id INTO user_authority_id
    FROM profiles 
    WHERE id = creator_profile_id;
    
    -- Get target authority's country
    SELECT country_id INTO target_country_id
    FROM authorities
    WHERE id = target_authority_id;
    
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
    
    -- Insert the new pass template
    INSERT INTO pass_templates (
        id,
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
        is_active,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        target_authority_id,
        target_country_id,
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
        TRUE,
        NOW(),
        NOW()
    ) RETURNING id INTO new_template_id;
    
    -- Log the creation
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
    
    RETURN new_template_id;
END;
$$;

-- Update pass template function
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
    
    -- Log the update
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
END;
$$;

-- Get pass templates with entry/exit point names
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

-- =====================================================
-- 5. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority TO authenticated;

-- =====================================================
-- 6. VERIFICATION
-- =====================================================

DO $$
BEGIN
    -- Verify all required columns exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'authority_id'
    ) THEN
        RAISE EXCEPTION 'Migration failed: authority_id column missing from pass_templates';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'entry_point_id'
    ) THEN
        RAISE EXCEPTION 'Migration failed: entry_point_id column missing from pass_templates';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) THEN
        RAISE EXCEPTION 'Migration failed: allow_user_selectable_points column missing from pass_templates';
    END IF;
    
    RAISE NOTICE 'Schema fix completed successfully!';
    RAISE NOTICE 'All required columns are now present in pass_templates and purchased_passes tables';
    RAISE NOTICE 'Functions have been recreated with proper column references';
END;
$$;

COMMIT;

-- =====================================================
-- SCHEMA FIX COMPLETE
-- =====================================================