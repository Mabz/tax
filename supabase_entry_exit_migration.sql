-- =====================================================
-- Entry/Exit Points Migration Script for Supabase
-- =====================================================
-- This script migrates from single border_id to entry_point_id/exit_point_id system
-- Safe to run in development - drops and recreates functions

BEGIN;

-- =====================================================
-- 1. UPDATE PASS_TEMPLATES TABLE SCHEMA
-- =====================================================

-- Add new columns to pass_templates
ALTER TABLE pass_templates 
ADD COLUMN IF NOT EXISTS entry_point_id UUID REFERENCES borders(id),
ADD COLUMN IF NOT EXISTS exit_point_id UUID REFERENCES borders(id),
ADD COLUMN IF NOT EXISTS allow_user_selectable_points BOOLEAN DEFAULT FALSE;

-- Migrate existing border_id data to entry_point_id
UPDATE pass_templates 
SET entry_point_id = border_id 
WHERE border_id IS NOT NULL AND entry_point_id IS NULL;

-- Add comment for clarity
COMMENT ON COLUMN pass_templates.entry_point_id IS 'Border where vehicles can enter (replaces border_id)';
COMMENT ON COLUMN pass_templates.exit_point_id IS 'Border where vehicles can exit (optional)';
COMMENT ON COLUMN pass_templates.allow_user_selectable_points IS 'Whether users can select different entry/exit points when purchasing';

-- =====================================================
-- 2. UPDATE PURCHASED_PASSES TABLE SCHEMA
-- =====================================================

-- Add new columns to purchased_passes
ALTER TABLE purchased_passes 
ADD COLUMN IF NOT EXISTS entry_point_id UUID REFERENCES borders(id),
ADD COLUMN IF NOT EXISTS exit_point_id UUID REFERENCES borders(id);

-- Migrate existing border_id data to entry_point_id
UPDATE purchased_passes 
SET entry_point_id = border_id 
WHERE border_id IS NOT NULL AND entry_point_id IS NULL;

-- Add comment for clarity
COMMENT ON COLUMN purchased_passes.entry_point_id IS 'Selected entry point for this pass (replaces border_id)';
COMMENT ON COLUMN purchased_passes.exit_point_id IS 'Selected exit point for this pass (optional)';

-- =====================================================
-- 3. DROP EXISTING FUNCTIONS (Development Safe)
-- =====================================================

-- Drop functions that need to be updated (with CASCADE to handle dependencies)
DROP FUNCTION IF EXISTS create_pass_template CASCADE;
DROP FUNCTION IF EXISTS update_pass_template CASCADE;
DROP FUNCTION IF EXISTS get_pass_templates_for_authority CASCADE;
DROP FUNCTION IF EXISTS issue_pass_from_template CASCADE;

-- =====================================================
-- 4. CREATE UPDATED PASS TEMPLATE FUNCTIONS
-- =====================================================

-- Create pass template with entry/exit points
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
BEGIN
    -- Get user's authority
    SELECT authority_id INTO user_authority_id
    FROM profiles 
    WHERE id = creator_profile_id;
    
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
    
    -- Get country_id from authority
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
        is_active
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
        allow_user_selectable_points,
        TRUE
    FROM authorities a
    WHERE a.id = target_authority_id
    RETURNING id INTO new_template_id;
    
    -- Log the creation
    INSERT INTO audit_logs (
        table_name,
        record_id,
        action,
        old_values,
        new_values,
        profile_id
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
        creator_profile_id
    );
    
    RETURN new_template_id;
END;
$$;

-- Update pass template with entry/exit points
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
        profile_id
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
        user_profile_id
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
-- 5. CREATE UPDATED PASS ISSUANCE FUNCTION
-- =====================================================

-- Issue pass from template with entry/exit point selection
CREATE OR REPLACE FUNCTION issue_pass_from_template(
    vehicle_id_param UUID,
    pass_template_id UUID,
    activation_date DATE,
    selected_entry_point_id UUID DEFAULT NULL,
    selected_exit_point_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    template_record RECORD;
    vehicle_record RECORD;
    new_pass_id UUID;
    user_profile_id UUID;
    pass_description TEXT;
    vehicle_description TEXT;
    qr_data JSONB;
    short_code TEXT;
    pass_hash TEXT;
    expires_at TIMESTAMP;
BEGIN
    -- Get current user
    user_profile_id := auth.uid();
    
    -- Get template details
    SELECT * INTO template_record
    FROM pass_templates pt
    WHERE pt.id = pass_template_id AND pt.is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass template not found or inactive';
    END IF;
    
    -- Get vehicle details (if provided)
    IF vehicle_id_param IS NOT NULL THEN
        SELECT * INTO vehicle_record
        FROM vehicles v
        WHERE v.id = vehicle_id_param AND v.profile_id = user_profile_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Vehicle not found or not owned by user';
        END IF;
        
        vehicle_description := vehicle_record.description;
    ELSE
        vehicle_description := 'General Pass';
    END IF;
    
    -- Determine entry/exit points to use
    -- If template allows user selection and user provided points, use those
    -- Otherwise use template defaults
    IF template_record.allow_user_selectable_points THEN
        -- Use user selections if provided, otherwise fall back to template defaults
        selected_entry_point_id := COALESCE(selected_entry_point_id, template_record.entry_point_id);
        selected_exit_point_id := COALESCE(selected_exit_point_id, template_record.exit_point_id);
        
        -- Validate user selections belong to the authority
        IF selected_entry_point_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM borders 
            WHERE id = selected_entry_point_id AND authority_id = template_record.authority_id
        ) THEN
            RAISE EXCEPTION 'Selected entry point is not valid for this authority';
        END IF;
        
        IF selected_exit_point_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM borders 
            WHERE id = selected_exit_point_id AND authority_id = template_record.authority_id
        ) THEN
            RAISE EXCEPTION 'Selected exit point is not valid for this authority';
        END IF;
    ELSE
        -- Use template defaults only
        selected_entry_point_id := template_record.entry_point_id;
        selected_exit_point_id := template_record.exit_point_id;
    END IF;
    
    -- Calculate expiration date
    expires_at := (activation_date + INTERVAL '1 day' * template_record.expiration_days)::TIMESTAMP;
    
    -- Generate pass description
    pass_description := template_record.description;
    
    -- Generate unique identifiers
    new_pass_id := gen_random_uuid();
    short_code := UPPER(SUBSTRING(REPLACE(new_pass_id::TEXT, '-', ''), 1, 8));
    short_code := SUBSTRING(short_code, 1, 4) || '-' || SUBSTRING(short_code, 5, 4);
    pass_hash := encode(digest(new_pass_id::TEXT || user_profile_id::TEXT, 'sha256'), 'hex');
    
    -- Create QR data
    qr_data := jsonb_build_object(
        'passId', new_pass_id,
        'passDescription', pass_description,
        'vehicleDescription', vehicle_description,
        'issuedAt', activation_date,
        'expiresAt', expires_at::DATE,
        'amount', template_record.tax_amount,
        'currency', template_record.currency_code,
        'entries', template_record.entry_limit || '/' || template_record.entry_limit
    );
    
    -- Insert the purchased pass
    INSERT INTO purchased_passes (
        id,
        profile_id,
        vehicle_id,
        pass_template_id,
        authority_id,
        country_id,
        entry_point_id,
        exit_point_id,
        pass_description,
        vehicle_description,
        entry_limit,
        entries_remaining,
        issued_at,
        activation_date,
        expires_at,
        status,
        current_status,
        currency,
        amount,
        qr_data,
        short_code,
        pass_hash
    ) VALUES (
        new_pass_id,
        user_profile_id,
        vehicle_id_param,
        pass_template_id,
        template_record.authority_id,
        template_record.country_id,
        selected_entry_point_id,
        selected_exit_point_id,
        pass_description,
        vehicle_description,
        template_record.entry_limit,
        template_record.entry_limit,
        NOW(),
        activation_date::TIMESTAMP,
        expires_at,
        'active',
        'unused',
        template_record.currency_code,
        template_record.tax_amount,
        qr_data,
        short_code,
        pass_hash
    );
    
    -- Log the issuance
    INSERT INTO audit_logs (
        table_name,
        record_id,
        action,
        new_values,
        profile_id
    ) VALUES (
        'purchased_passes',
        new_pass_id,
        'CREATE',
        jsonb_build_object(
            'pass_template_id', pass_template_id,
            'entry_point_id', selected_entry_point_id,
            'exit_point_id', selected_exit_point_id,
            'amount', template_record.tax_amount
        ),
        user_profile_id
    );
    
    RETURN new_pass_id;
END;
$$;

-- =====================================================
-- 6. CREATE VIEW FOR ENHANCED PASS QUERIES
-- =====================================================

-- Create or replace view for pass queries with entry/exit point names
CREATE OR REPLACE VIEW purchased_passes_with_details AS
SELECT 
    pp.id,
    pp.profile_id,
    pp.vehicle_id,
    pp.pass_template_id,
    pp.authority_id,
    pp.country_id,
    pp.entry_point_id,
    pp.exit_point_id,
    pp.pass_description,
    pp.vehicle_description,
    pp.entry_limit,
    pp.entries_remaining,
    pp.issued_at,
    pp.activation_date,
    pp.expires_at,
    pp.status,
    pp.current_status,
    pp.currency,
    pp.amount,
    pp.qr_data,
    pp.short_code,
    pp.pass_hash,
    pp.secure_code,
    pp.secure_code_expires_at,
    pp.created_at,
    pp.updated_at,
    entry_border.name AS entry_point_name,
    exit_border.name AS exit_point_name,
    a.name AS authority_name,
    c.name AS country_name
FROM purchased_passes pp
LEFT JOIN borders entry_border ON pp.entry_point_id = entry_border.id
LEFT JOIN borders exit_border ON pp.exit_point_id = exit_border.id
LEFT JOIN authorities a ON pp.authority_id = a.id
LEFT JOIN countries c ON pp.country_id = c.id;

-- =====================================================
-- 7. UPDATE RLS POLICIES (if needed)
-- =====================================================

-- Update RLS policies to include new columns (example)
-- Note: Adjust based on your existing RLS setup

-- Drop existing policies if they need updating
-- DROP POLICY IF EXISTS "Users can view their own passes" ON purchased_passes;

-- Recreate with new columns if needed
-- CREATE POLICY "Users can view their own passes" ON purchased_passes
--     FOR SELECT USING (profile_id = auth.uid());

-- =====================================================
-- 8. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Add indexes for new foreign key columns
CREATE INDEX IF NOT EXISTS idx_pass_templates_entry_point_id ON pass_templates(entry_point_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_exit_point_id ON pass_templates(exit_point_id);
CREATE INDEX IF NOT EXISTS idx_purchased_passes_entry_point_id ON purchased_passes(entry_point_id);
CREATE INDEX IF NOT EXISTS idx_purchased_passes_exit_point_id ON purchased_passes(exit_point_id);

-- Add composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_pass_templates_authority_active ON pass_templates(authority_id, is_active);
CREATE INDEX IF NOT EXISTS idx_purchased_passes_profile_status ON purchased_passes(profile_id, status);

-- =====================================================
-- 9. GRANT PERMISSIONS
-- =====================================================

-- Grant execute permissions on functions to authenticated users
GRANT EXECUTE ON FUNCTION create_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_template TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority TO authenticated;
GRANT EXECUTE ON FUNCTION issue_pass_from_template TO authenticated;

-- Grant select on view
GRANT SELECT ON purchased_passes_with_details TO authenticated;

-- =====================================================
-- 10. VERIFICATION QUERIES
-- =====================================================

-- Verify the migration worked
DO $$
BEGIN
    -- Check if columns were added
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'entry_point_id'
    ) THEN
        RAISE EXCEPTION 'Migration failed: entry_point_id column not found in pass_templates';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pass_templates' AND column_name = 'allow_user_selectable_points'
    ) THEN
        RAISE EXCEPTION 'Migration failed: allow_user_selectable_points column not found in pass_templates';
    END IF;
    
    RAISE NOTICE 'Migration completed successfully!';
    RAISE NOTICE 'New columns added: entry_point_id, exit_point_id, allow_user_selectable_points';
    RAISE NOTICE 'Functions updated: create_pass_template, update_pass_template, get_pass_templates_for_authority, issue_pass_from_template';
    RAISE NOTICE 'View created: purchased_passes_with_details';
END;
$$;

COMMIT;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- 
-- Summary of changes:
-- 1. Added entry_point_id, exit_point_id, allow_user_selectable_points to pass_templates
-- 2. Added entry_point_id, exit_point_id to purchased_passes  
-- 3. Migrated existing border_id data to entry_point_id
-- 4. Updated all functions to support entry/exit points
-- 5. Created view for enhanced queries with point names
-- 6. Added indexes for performance
-- 7. Added verification checks
--
-- Next steps:
-- 1. Test the functions with your Flutter app
-- 2. Verify data migration worked correctly
-- 3. Update any remaining queries to use new column names
-- 4. Consider dropping old border_id columns after verification (optional)
--
-- =====================================================