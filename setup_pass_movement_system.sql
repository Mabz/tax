-- Complete setup script for the pass movement system
-- Run this script in Supabase to create all necessary functions and tables

-- ============================================================================
-- STEP 1: Create/Update Tables
-- ============================================================================

-- Ensure purchased_passes has required columns
DO $$
BEGIN
    -- Add current_status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'current_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN current_status TEXT DEFAULT 'unused';
        COMMENT ON COLUMN purchased_passes.current_status IS 'Current status: unused, checked_in, checked_out, expired';
        RAISE NOTICE 'Added current_status column to purchased_passes';
    END IF;
    
    -- Add entries_remaining column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'entries_remaining'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN entries_remaining INTEGER;
        COMMENT ON COLUMN purchased_passes.entries_remaining IS 'Number of entries remaining on the pass';
        RAISE NOTICE 'Added entries_remaining column to purchased_passes';
        
        -- Initialize entries_remaining for existing passes
        UPDATE purchased_passes pp
        SET entries_remaining = COALESCE(pt.max_entries, 1)
        FROM pass_templates pt
        WHERE pp.pass_template_id = pt.id
        AND pp.entries_remaining IS NULL;
        
        -- For passes without template reference, set default
        UPDATE purchased_passes 
        SET entries_remaining = 1 
        WHERE entries_remaining IS NULL;
        
        RAISE NOTICE 'Initialized entries_remaining for existing passes';
    END IF;
END $$;

-- Create border_official_borders table if it doesn't exist
DO $$
BEGIN
    -- Check if border_official_borders table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'border_official_borders' 
        AND table_schema = 'public'
    ) THEN
        -- Check if profiles table exists before creating foreign keys
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'profiles' 
            AND table_schema = 'public'
        ) THEN
            -- Create with foreign keys to profiles
            CREATE TABLE border_official_borders (
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
            RAISE NOTICE 'Created border_official_borders table with profiles foreign keys';
        ELSE
            -- Create without foreign keys to profiles (will add later)
            CREATE TABLE border_official_borders (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                profile_id UUID NOT NULL,
                border_id UUID NOT NULL REFERENCES borders(id) ON DELETE CASCADE,
                can_check_in BOOLEAN DEFAULT true,
                can_check_out BOOLEAN DEFAULT true,
                assigned_by UUID,
                assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                revoked_by UUID,
                revoked_at TIMESTAMP WITH TIME ZONE,
                is_active BOOLEAN DEFAULT true,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            RAISE NOTICE 'Created border_official_borders table without profiles foreign keys (profiles table not found)';
        END IF;
    ELSE
        RAISE NOTICE 'border_official_borders table already exists';
    END IF;
END $$;

-- Create pass_movements table if it doesn't exist
DO $$
BEGIN
    -- Check if pass_movements table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'pass_movements' 
        AND table_schema = 'public'
    ) THEN
        -- Check if profiles table exists before creating foreign key
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'profiles' 
            AND table_schema = 'public'
        ) THEN
            -- Create with foreign key to profiles
            CREATE TABLE pass_movements (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                pass_id UUID NOT NULL REFERENCES purchased_passes(id) ON DELETE CASCADE,
                border_id UUID NOT NULL REFERENCES borders(id) ON DELETE CASCADE,
                official_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
                movement_type TEXT NOT NULL CHECK (movement_type IN ('check_in', 'check_out')),
                previous_status TEXT NOT NULL,
                new_status TEXT NOT NULL,
                entries_deducted INTEGER DEFAULT 0,
                latitude DECIMAL(10, 8),
                longitude DECIMAL(11, 8),
                metadata JSONB DEFAULT '{}',
                processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            RAISE NOTICE 'Created pass_movements table with profiles foreign key';
        ELSE
            -- Create without foreign key to profiles (will add later)
            CREATE TABLE pass_movements (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                pass_id UUID NOT NULL REFERENCES purchased_passes(id) ON DELETE CASCADE,
                border_id UUID NOT NULL REFERENCES borders(id) ON DELETE CASCADE,
                official_id UUID NOT NULL,
                movement_type TEXT NOT NULL CHECK (movement_type IN ('check_in', 'check_out')),
                previous_status TEXT NOT NULL,
                new_status TEXT NOT NULL,
                entries_deducted INTEGER DEFAULT 0,
                latitude DECIMAL(10, 8),
                longitude DECIMAL(11, 8),
                metadata JSONB DEFAULT '{}',
                processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            RAISE NOTICE 'Created pass_movements table without profiles foreign key (profiles table not found)';
        END IF;
    ELSE
        RAISE NOTICE 'pass_movements table already exists';
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Create Indexes
-- ============================================================================

-- Indexes for border_official_borders
CREATE INDEX IF NOT EXISTS idx_border_official_borders_profile_id ON border_official_borders(profile_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_border_id ON border_official_borders(border_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_active ON border_official_borders(is_active);

-- Indexes for pass_movements
CREATE INDEX IF NOT EXISTS idx_pass_movements_pass_id ON pass_movements(pass_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_border_id ON pass_movements(border_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_official_id ON pass_movements(official_id);
CREATE INDEX IF NOT EXISTS idx_pass_movements_processed_at ON pass_movements(processed_at);

-- ============================================================================
-- STEP 3: Enable RLS and Create Policies
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE border_official_borders ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_movements ENABLE ROW LEVEL SECURITY;

-- RLS policies for border_official_borders
DROP POLICY IF EXISTS "Officials can view their own assignments" ON border_official_borders;
CREATE POLICY "Officials can view their own assignments" ON border_official_borders
    FOR SELECT USING (profile_id = auth.uid());

DROP POLICY IF EXISTS "Managers can manage assignments" ON border_official_borders;
CREATE POLICY "Managers can manage assignments" ON border_official_borders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name IN ('country_admin', 'authority_admin', 'super_admin')
        )
    );

-- RLS policies for pass_movements
DROP POLICY IF EXISTS "Users can view their own pass movements" ON pass_movements;
CREATE POLICY "Users can view their own pass movements" ON pass_movements
    FOR SELECT USING (
        pass_id IN (
            SELECT id FROM purchased_passes WHERE profile_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Border officials can view movements at their borders" ON pass_movements;
CREATE POLICY "Border officials can view movements at their borders" ON pass_movements
    FOR SELECT USING (
        border_id IN (
            SELECT border_id FROM border_official_borders 
            WHERE profile_id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "Border officials can insert movements" ON pass_movements;
CREATE POLICY "Border officials can insert movements" ON pass_movements
    FOR INSERT WITH CHECK (
        border_id IN (
            SELECT border_id FROM border_official_borders 
            WHERE profile_id = auth.uid() AND is_active = true
        )
    );

-- ============================================================================
-- STEP 4: Create Functions
-- ============================================================================

-- Main function: process_pass_movement
CREATE OR REPLACE FUNCTION process_pass_movement(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_official_id UUID;
    v_pass_record RECORD;
    v_movement_type TEXT;
    v_previous_status TEXT;
    v_new_status TEXT;
    v_entries_deducted INTEGER := 0;
    v_movement_id UUID;
    v_can_check_in BOOLEAN := false;
    v_can_check_out BOOLEAN := false;
    v_entries_remaining INTEGER;
BEGIN
    -- Get the current user (border official)
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if the official is assigned to this border and get permissions
    SELECT can_check_in, can_check_out
    INTO v_can_check_in, v_can_check_out
    FROM border_official_borders
    WHERE profile_id = v_official_id 
      AND border_id = p_border_id 
      AND is_active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Official not assigned to this border';
    END IF;
    
    -- Get the current pass information
    SELECT *
    INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass not found';
    END IF;
    
    -- Check if pass is expired
    IF v_pass_record.expires_at < NOW() THEN
        RAISE EXCEPTION 'Pass has expired';
    END IF;
    
    -- Determine movement type based on current status
    v_previous_status := COALESCE(v_pass_record.current_status, 'unused');
    
    IF v_previous_status IN ('unused', 'checked_out') THEN
        v_movement_type := 'check_in';
        v_new_status := 'checked_in';
        v_entries_deducted := 1;
        
        -- Check if official can perform check-in
        IF NOT v_can_check_in THEN
            RAISE EXCEPTION 'Official does not have check-in permissions for this border';
        END IF;
        
        -- Check if pass has remaining entries
        IF COALESCE(v_pass_record.entries_remaining, 0) < 1 THEN
            RAISE EXCEPTION 'No entries remaining on pass';
        END IF;
        
    ELSIF v_previous_status = 'checked_in' THEN
        v_movement_type := 'check_out';
        v_new_status := 'checked_out';
        v_entries_deducted := 0;
        
        -- Check if official can perform check-out
        IF NOT v_can_check_out THEN
            RAISE EXCEPTION 'Official does not have check-out permissions for this border';
        END IF;
        
    ELSE
        RAISE EXCEPTION 'Invalid pass status for movement: %', v_previous_status;
    END IF;
    
    -- Calculate new entries remaining
    v_entries_remaining := COALESCE(v_pass_record.entries_remaining, 0) - v_entries_deducted;
    
    -- Create the movement record
    INSERT INTO pass_movements (
        pass_id,
        border_id,
        official_id,
        movement_type,
        previous_status,
        new_status,
        entries_deducted,
        latitude,
        longitude,
        metadata,
        processed_at
    ) VALUES (
        p_pass_id,
        p_border_id,
        v_official_id,
        v_movement_type,
        v_previous_status,
        v_new_status,
        v_entries_deducted,
        p_latitude,
        p_longitude,
        p_metadata,
        NOW()
    ) RETURNING id INTO v_movement_id;
    
    -- Update the pass status and entries
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Return the result in the expected format
    RETURN jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_deducted,
        'entries_remaining', v_entries_remaining,
        'processed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise with more context
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Function: can_official_process_movement
CREATE OR REPLACE FUNCTION can_official_process_movement(
    p_border_id UUID,
    p_movement_type TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_official_id UUID;
    v_can_check_in BOOLEAN := false;
    v_can_check_out BOOLEAN := false;
BEGIN
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RETURN false;
    END IF;
    
    SELECT can_check_in, can_check_out
    INTO v_can_check_in, v_can_check_out
    FROM border_official_borders
    WHERE profile_id = v_official_id 
      AND border_id = p_border_id 
      AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    IF p_movement_type = 'check_in' THEN
        RETURN v_can_check_in;
    ELSIF p_movement_type = 'check_out' THEN
        RETURN v_can_check_out;
    ELSE
        RETURN false;
    END IF;
END;
$$;

-- Function: get_pass_movement_history
CREATE OR REPLACE FUNCTION get_pass_movement_history(
    p_pass_id UUID
)
RETURNS TABLE (
    movement_id UUID,
    border_name TEXT,
    official_name TEXT,
    movement_type TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    processed_at TIMESTAMP WITH TIME ZONE,
    entries_deducted INTEGER,
    previous_status TEXT,
    new_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user can access this pass
    IF NOT EXISTS (
        SELECT 1 FROM purchased_passes 
        WHERE id = p_pass_id 
        AND (
            profile_id = auth.uid() -- Pass owner
            OR EXISTS ( -- Or border official who can see movements
                SELECT 1 FROM pass_movements pm
                JOIN border_official_borders bob ON pm.border_id = bob.border_id
                WHERE pm.pass_id = p_pass_id 
                AND bob.profile_id = auth.uid()
                AND bob.is_active = true
            )
        )
    ) THEN
        RAISE EXCEPTION 'Access denied to pass movement history';
    END IF;
    
    -- Check if profiles table exists for the join
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'profiles' 
        AND table_schema = 'public'
    ) THEN
        RETURN QUERY
        SELECT 
            pm.id as movement_id,
            b.name as border_name,
            COALESCE(p.full_name, 'Unknown Official') as official_name,
            pm.movement_type,
            pm.latitude,
            pm.longitude,
            pm.processed_at,
            pm.entries_deducted,
            pm.previous_status,
            pm.new_status
        FROM pass_movements pm
        JOIN borders b ON pm.border_id = b.id
        LEFT JOIN profiles p ON pm.official_id = p.id
        WHERE pm.pass_id = p_pass_id
        ORDER BY pm.processed_at DESC;
    ELSE
        -- Return without profile information if profiles table doesn't exist
        RETURN QUERY
        SELECT 
            pm.id as movement_id,
            b.name as border_name,
            'Unknown Official'::TEXT as official_name,
            pm.movement_type,
            pm.latitude,
            pm.longitude,
            pm.processed_at,
            pm.entries_deducted,
            pm.previous_status,
            pm.new_status
        FROM pass_movements pm
        JOIN borders b ON pm.border_id = b.id
        WHERE pm.pass_id = p_pass_id
        ORDER BY pm.processed_at DESC;
    END IF;
END;
$$;

-- Function: assign_official_to_border_with_permissions
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
    
    -- Deactivate any existing assignments for this official at this border
    UPDATE border_official_borders
    SET is_active = false, updated_at = NOW()
    WHERE profile_id = target_profile_id 
      AND border_id = target_border_id
      AND is_active = true;
    
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

-- Function: revoke_official_from_border
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

-- Function: get_border_assignments_with_permissions
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
    -- Check if profiles table exists for the join
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'profiles' 
        AND table_schema = 'public'
    ) THEN
        RETURN QUERY
        SELECT 
            bob.id,
            bob.profile_id,
            bob.border_id,
            COALESCE(p.full_name, 'Unknown') as official_name,
            COALESCE(p.email, 'Unknown') as official_email,
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
    ELSE
        -- Return without profile information if profiles table doesn't exist
        RETURN QUERY
        SELECT 
            bob.id,
            bob.profile_id,
            bob.border_id,
            'Unknown'::TEXT as official_name,
            'Unknown'::TEXT as official_email,
            b.name as border_name,
            bob.can_check_in,
            bob.can_check_out,
            bob.assigned_at
        FROM border_official_borders bob
        JOIN borders b ON bob.border_id = b.id
        JOIN authorities a ON b.authority_id = a.id
        WHERE bob.is_active = true
          AND a.country_id = country_id_param
        ORDER BY b.name;
    END IF;
END;
$$;

-- ============================================================================
-- STEP 5: Grant Permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION can_official_process_movement TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_movement_history TO authenticated;
GRANT EXECUTE ON FUNCTION assign_official_to_border_with_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_official_from_border TO authenticated;
GRANT EXECUTE ON FUNCTION get_border_assignments_with_permissions TO authenticated;

-- ============================================================================
-- STEP 6: Add Comments
-- ============================================================================

COMMENT ON FUNCTION process_pass_movement IS 'Main function to process pass check-in/check-out movements at borders';
COMMENT ON FUNCTION can_official_process_movement IS 'Checks if current official can process specific movement type at border';
COMMENT ON FUNCTION get_pass_movement_history IS 'Returns movement history for a specific pass';
COMMENT ON FUNCTION assign_official_to_border_with_permissions IS 'Assigns a border official to a border with specific permissions';
COMMENT ON FUNCTION revoke_official_from_border IS 'Revokes a border official assignment from a border';
COMMENT ON FUNCTION get_border_assignments_with_permissions IS 'Gets all border assignments with permissions for a country';

COMMENT ON TABLE border_official_borders IS 'Manages border official assignments and their permissions';
COMMENT ON TABLE pass_movements IS 'Stores all pass movement records (check-ins and check-outs)';

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Pass Movement System Setup Complete!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Created/Updated:';
    RAISE NOTICE '- Tables: border_official_borders, pass_movements';
    RAISE NOTICE '- Functions: process_pass_movement, can_official_process_movement';
    RAISE NOTICE '- Functions: get_pass_movement_history, assign_official_to_border_with_permissions';
    RAISE NOTICE '- Functions: revoke_official_from_border, get_border_assignments_with_permissions';
    RAISE NOTICE '- RLS policies and indexes';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'The system is now ready to process pass movements!';
    RAISE NOTICE '=================================================================';
END $$;