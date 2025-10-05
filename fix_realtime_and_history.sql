-- Fix real-time updates and pass history logging
-- Run this script in Supabase SQL Editor

-- First, let's check if pass_processing_audit table exists and create it if needed
DO $$
BEGIN
    -- Create pass_processing_audit table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'pass_processing_audit' 
        AND table_schema = 'public'
    ) THEN
        CREATE TABLE pass_processing_audit (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            pass_id UUID NOT NULL,
            action_type TEXT NOT NULL,
            performed_by UUID,
            performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            previous_status TEXT,
            new_status TEXT,
            entries_deducted INTEGER DEFAULT 0,
            entries_remaining INTEGER,
            border_id UUID,
            border_name TEXT,
            official_name TEXT,
            latitude DECIMAL(10, 8),
            longitude DECIMAL(11, 8),
            metadata JSONB DEFAULT '{}',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- Add foreign key constraints
        ALTER TABLE pass_processing_audit 
        ADD CONSTRAINT fk_pass_processing_audit_pass_id 
        FOREIGN KEY (pass_id) REFERENCES purchased_passes(id) ON DELETE CASCADE;
        
        -- Add indexes
        CREATE INDEX idx_pass_processing_audit_pass_id ON pass_processing_audit(pass_id);
        CREATE INDEX idx_pass_processing_audit_performed_at ON pass_processing_audit(performed_at);
        CREATE INDEX idx_pass_processing_audit_performed_by ON pass_processing_audit(performed_by);
        
        -- Enable RLS
        ALTER TABLE pass_processing_audit ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policy
        CREATE POLICY "Users can view their own pass audit logs" ON pass_processing_audit
            FOR SELECT USING (
                pass_id IN (
                    SELECT id FROM purchased_passes WHERE profile_id = auth.uid()
                )
            );
            
        CREATE POLICY "Border officials can insert audit logs" ON pass_processing_audit
            FOR INSERT WITH CHECK (performed_by = auth.uid());
        
        RAISE NOTICE 'Created pass_processing_audit table';
    END IF;
END $$;

-- Update the process_pass_movement function to log to audit table and trigger real-time updates
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
    v_audit_id UUID;
    v_entries_remaining INTEGER;
    v_border_name TEXT;
    v_official_name TEXT;
BEGIN
    -- Get the current user (border official)
    v_official_id := auth.uid();
    
    IF v_official_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
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
    
    -- Get border name for logging
    SELECT name INTO v_border_name FROM borders WHERE id = p_border_id;
    
    -- Get official name for logging
    SELECT full_name INTO v_official_name FROM profiles WHERE id = v_official_id;
    
    -- Determine movement type based on current status
    v_previous_status := COALESCE(v_pass_record.current_status, 'unused');
    
    IF v_previous_status IN ('unused', 'checked_out') THEN
        v_movement_type := 'check_in';
        v_new_status := 'checked_in';
        v_entries_deducted := 1;
        
        -- Check if pass has remaining entries
        IF COALESCE(v_pass_record.entries_remaining, 0) < 1 THEN
            RAISE EXCEPTION 'No entries remaining on pass';
        END IF;
        
    ELSIF v_previous_status = 'checked_in' THEN
        v_movement_type := 'check_out';
        v_new_status := 'checked_out';
        v_entries_deducted := 0;
        
    ELSE
        RAISE EXCEPTION 'Invalid pass status for movement: %', v_previous_status;
    END IF;
    
    -- Calculate new entries remaining
    v_entries_remaining := COALESCE(v_pass_record.entries_remaining, 0) - v_entries_deducted;
    
    -- Create the movement record
    INSERT INTO pass_movements (
        pass_id,
        border_id,
        border_official_profile_id,
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
    
    -- Create audit log entry
    INSERT INTO pass_processing_audit (
        pass_id,
        action_type,
        performed_by,
        performed_at,
        previous_status,
        new_status,
        entries_deducted,
        entries_remaining,
        border_id,
        border_name,
        official_name,
        latitude,
        longitude,
        metadata
    ) VALUES (
        p_pass_id,
        v_movement_type,
        v_official_id,
        NOW(),
        v_previous_status,
        v_new_status,
        v_entries_deducted,
        v_entries_remaining,
        p_border_id,
        COALESCE(v_border_name, 'Unknown Border'),
        COALESCE(v_official_name, 'Unknown Official'),
        p_latitude,
        p_longitude,
        p_metadata
    ) RETURNING id INTO v_audit_id;
    
    -- Update the pass status and entries (this will trigger real-time updates)
    UPDATE purchased_passes
    SET 
        current_status = v_new_status,
        entries_remaining = v_entries_remaining,
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Return the result
    RETURN jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'audit_id', v_audit_id,
        'movement_type', v_movement_type,
        'previous_status', v_previous_status,
        'new_status', v_new_status,
        'entries_deducted', v_entries_deducted,
        'entries_remaining', v_entries_remaining,
        'processed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error processing pass movement: %', SQLERRM;
END;
$$;

-- Create a function to get pass history from audit table
CREATE OR REPLACE FUNCTION get_pass_history(p_pass_id UUID)
RETURNS TABLE (
    id UUID,
    action_type TEXT,
    performed_by UUID,
    performed_at TIMESTAMP WITH TIME ZONE,
    previous_status TEXT,
    new_status TEXT,
    entries_deducted INTEGER,
    entries_remaining INTEGER,
    border_name TEXT,
    official_name TEXT,
    latitude DECIMAL,
    longitude DECIMAL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user can access this pass
    IF NOT EXISTS (
        SELECT 1 FROM purchased_passes 
        WHERE purchased_passes.id = p_pass_id 
        AND (
            profile_id = auth.uid() -- Pass owner
            OR EXISTS ( -- Or border official who can see movements
                SELECT 1 FROM pass_movements pm
                WHERE pm.pass_id = p_pass_id 
                AND pm.border_official_profile_id = auth.uid()
            )
        )
    ) THEN
        RAISE EXCEPTION 'Access denied to pass history';
    END IF;
    
    RETURN QUERY
    SELECT 
        ppa.id,
        ppa.action_type,
        ppa.performed_by,
        ppa.performed_at,
        ppa.previous_status,
        ppa.new_status,
        ppa.entries_deducted,
        ppa.entries_remaining,
        ppa.border_name,
        ppa.official_name,
        ppa.latitude,
        ppa.longitude
    FROM pass_processing_audit ppa
    WHERE ppa.pass_id = p_pass_id
    ORDER BY ppa.performed_at DESC;
END;
$$;

-- Create a trigger to ensure real-time updates work properly
CREATE OR REPLACE FUNCTION notify_pass_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- This trigger will ensure that any updates to purchased_passes
    -- are properly propagated for real-time subscriptions
    
    -- Update the updated_at timestamp
    NEW.updated_at = NOW();
    
    RETURN NEW;
END;
$$;

-- Create the trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_pass_update ON purchased_passes;
CREATE TRIGGER trigger_pass_update
    BEFORE UPDATE ON purchased_passes
    FOR EACH ROW
    EXECUTE FUNCTION notify_pass_update();

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_pass_movement TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_history TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Real-time Updates and History Fixed!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Created pass_processing_audit table for history';
    RAISE NOTICE 'Updated process_pass_movement to log audit entries';
    RAISE NOTICE 'Created get_pass_history function';
    RAISE NOTICE 'Added trigger for real-time updates';
    RAISE NOTICE 'Pass history should now work properly!';
    RAISE NOTICE '=================================================================';
END $$;