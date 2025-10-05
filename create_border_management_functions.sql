-- Create supporting functions for border official management
-- These functions are referenced in the enhanced_border_service.dart

-- Function to assign official to border with permissions
CREATE OR REPLACE FUNCTION assign_official_to_border_with_permissions(
    target_profile_id UUID,
    target_border_id UUID,
    can_check_in_param BOOLEAN DEFAULT true,
    can_check_out_param BOOLEAN DEFAULT true
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_user_id UUID;
BEGIN
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if the current user has permission to assign officials
    -- (This would typically check for admin or manager role)
    
    -- Deactivate any existing assignments for this official at this border
    UPDATE border_official_borders
    SET is_active = false, updated_at = NOW()
    WHERE profile_id = target_profile_id 
      AND border_id = target_border_id;
    
    -- Create new assignment
    INSERT INTO border_official_borders (
        profile_id,
        border_id,
        can_check_in,
        can_check_out,
        assigned_by,
        assigned_at,
        is_active
    ) VALUES (
        target_profile_id,
        target_border_id,
        can_check_in_param,
        can_check_out_param,
        v_current_user_id,
        NOW(),
        true
    );
END;
$$;

GRANT EXECUTE ON FUNCTION assign_official_to_border_with_permissions TO authenticated;

-- Function to revoke official from border
CREATE OR REPLACE FUNCTION revoke_official_from_border(
    target_profile_id UUID,
    target_border_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_user_id UUID;
BEGIN
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Deactivate the assignment
    UPDATE border_official_borders
    SET 
        is_active = false,
        updated_at = NOW(),
        revoked_by = v_current_user_id,
        revoked_at = NOW()
    WHERE profile_id = target_profile_id 
      AND border_id = target_border_id
      AND is_active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active assignment found for this official at this border';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION revoke_official_from_border TO authenticated;

-- Function to get border assignments with permissions
CREATE OR REPLACE FUNCTION get_border_assignments_with_permissions(
    country_id_param UUID
)
RETURNS TABLE (
    id UUID,
    profile_id UUID,
    border_id UUID,
    official_name TEXT,
    official_email TEXT,
    border_name TEXT,
    can_check_in BOOLEAN,
    can_check_out BOOLEAN,
    assigned_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bob.id,
        bob.profile_id,
        bob.border_id,
        p.full_name as official_name,
        p.email as official_email,
        b.name as border_name,
        bob.can_check_in,
        bob.can_check_out,
        bob.assigned_at
    FROM border_official_borders bob
    JOIN profiles p ON bob.profile_id = p.id
    JOIN borders b ON bob.border_id = b.id
    JOIN authorities a ON b.authority_id = a.id
    WHERE bob.is_active = true
      AND a.country_id = country_id_param
    ORDER BY b.name, p.full_name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_border_assignments_with_permissions TO authenticated;

-- Create the border_official_borders table if it doesn't exist
CREATE TABLE IF NOT EXISTS border_official_borders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    border_id UUID NOT NULL REFERENCES borders(id) ON DELETE CASCADE,
    can_check_in BOOLEAN DEFAULT true,
    can_check_out BOOLEAN DEFAULT true,
    assigned_by UUID REFERENCES profiles(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revoked_by UUID REFERENCES profiles(id),
    revoked_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_border_official_borders_profile_id ON border_official_borders(profile_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_border_id ON border_official_borders(border_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_active ON border_official_borders(is_active);

-- Enable RLS
ALTER TABLE border_official_borders ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Officials can view their own assignments" ON border_official_borders
    FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "Managers can view assignments in their country" ON border_official_borders
    FOR SELECT USING (
        border_id IN (
            SELECT b.id FROM borders b
            JOIN authorities a ON b.authority_id = a.id
            WHERE a.country_id IN (
                SELECT country_id FROM profile_roles pr
                JOIN roles r ON pr.role_id = r.id
                WHERE pr.profile_id = auth.uid()
                AND r.name IN ('country_admin', 'authority_admin')
            )
        )
    );

-- Add missing columns to purchased_passes if they don't exist
DO $$
BEGIN
    -- Add current_status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'current_status'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN current_status TEXT DEFAULT 'unused';
        COMMENT ON COLUMN purchased_passes.current_status IS 'Current status of the pass: unused, checked_in, checked_out, expired';
    END IF;
    
    -- Add entries_remaining column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'entries_remaining'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entries_remaining INTEGER;
        COMMENT ON COLUMN purchased_passes.entries_remaining IS 'Number of entries remaining on the pass';
        
        -- Initialize entries_remaining based on pass template
        UPDATE purchased_passes pp
        SET entries_remaining = pt.max_entries
        FROM pass_templates pt
        WHERE pp.pass_template_id = pt.id
        AND pp.entries_remaining IS NULL;
    END IF;
END $$;

-- Add comments
COMMENT ON FUNCTION assign_official_to_border_with_permissions IS 'Assigns a border official to a border with specific permissions';
COMMENT ON FUNCTION revoke_official_from_border IS 'Revokes a border official assignment from a border';
COMMENT ON FUNCTION get_border_assignments_with_permissions IS 'Gets all border assignments with permissions for a country';
COMMENT ON TABLE border_official_borders IS 'Manages border official assignments and their permissions';