-- Create pass verification functions for QR scanning and border control
-- This script creates the missing verify_pass function and related functionality

-- ============================================================================
-- STEP 1: Create Pass Verification Functions
-- ============================================================================

-- Function to verify a pass by QR code or backup code
CREATE OR REPLACE FUNCTION verify_pass(
    verification_code TEXT,
    is_qr_code BOOLEAN DEFAULT true
)
RETURNS TABLE (
    pass_id TEXT,
    vehicle_description TEXT,
    pass_description TEXT,
    entry_point_name TEXT,
    exit_point_name TEXT,
    entry_limit INTEGER,
    entries_remaining INTEGER,
    issued_at TIMESTAMP WITH TIME ZONE,
    activation_date TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    status TEXT,
    current_status TEXT,
    currency TEXT,
    amount DECIMAL,
    qr_code TEXT,
    short_code TEXT,
    pass_hash TEXT,
    authority_id TEXT,
    authority_name TEXT,
    country_name TEXT,
    entry_point_id TEXT,
    exit_point_id TEXT,
    vehicle_registration_number TEXT,
    vehicle_vin TEXT,
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_year INTEGER,
    vehicle_color TEXT,
    secure_code TEXT,
    secure_code_expires_at TIMESTAMP WITH TIME ZONE,
    qr_data JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass_id TEXT;
    v_qr_data JSONB;
BEGIN
    -- Log the input for debugging
    RAISE NOTICE 'verify_pass called with: %, is_qr_code: %', verification_code, is_qr_code;
    -- Extract pass ID based on verification method
    IF is_qr_code THEN
        -- For QR codes, handle JSON format first, then fallback to legacy formats
        DECLARE
            v_qr_json JSONB;
            v_qr_parts TEXT[];
            v_part TEXT;
        BEGIN
            -- Try to parse as JSON first (new format)
            BEGIN
                v_qr_json := verification_code::JSONB;
                
                -- Extract pass ID from JSON - try different possible keys
                IF v_qr_json ? 'id' THEN
                    v_pass_id := v_qr_json->>'id';
                ELSIF v_qr_json ? 'pass_id' THEN
                    v_pass_id := v_qr_json->>'pass_id';
                ELSIF v_qr_json ? 'profile_id' THEN
                    -- If no direct pass ID, try to find by profile_id and pass_hash
                    DECLARE
                        v_profile_id TEXT := v_qr_json->>'profile_id';
                        v_pass_hash TEXT := v_qr_json->>'pass_hash';
                        v_short_code TEXT := v_qr_json->>'short_code';
                    BEGIN
                        -- Try to find pass by hash first
                        IF v_pass_hash IS NOT NULL AND v_pass_hash != '' THEN
                            SELECT pp.id::text INTO v_pass_id
                            FROM purchased_passes pp
                            WHERE pp.pass_hash = v_pass_hash
                              AND pp.profile_id::text = v_profile_id
                              AND pp.status = 'active'
                              AND pp.expires_at > NOW()
                              AND pp.activation_date <= NOW()
                            LIMIT 1;
                        END IF;
                        
                        -- If not found by hash, try by short_code
                        IF v_pass_id IS NULL AND v_short_code IS NOT NULL AND v_short_code != '' THEN
                            SELECT pp.id::text INTO v_pass_id
                            FROM purchased_passes pp
                            WHERE pp.short_code = v_short_code
                              AND pp.profile_id::text = v_profile_id
                              AND pp.status = 'active'
                              AND pp.expires_at > NOW()
                              AND pp.activation_date <= NOW()
                            LIMIT 1;
                        END IF;
                    END;
                END IF;
                
                RAISE NOTICE 'Extracted pass_id from JSON QR: %', v_pass_id;
                
            EXCEPTION WHEN OTHERS THEN
                -- Not valid JSON, try legacy formats
                RAISE NOTICE 'QR code is not JSON, trying legacy formats';
                
                -- Handle legacy QR code formats:
                -- 1. Simple UUID: "12345678-1234-1234-1234-123456789012"
                -- 2. Pipe format: "PASS_ID|HASH|TIMESTAMP"
                -- 3. Key-value format: "id:12345678-1234-1234-1234-123456789012|hash:ABC123|expires:1234567890"
                
                IF verification_code ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
                    -- Format 1: Simple UUID
                    v_pass_id := verification_code;
                ELSIF verification_code LIKE '%:%' THEN
                    -- Format 3: Key-value pairs (id:value|hash:value|...)
                    v_qr_parts := string_to_array(verification_code, '|');
                    FOREACH v_part IN ARRAY v_qr_parts LOOP
                        IF v_part LIKE 'id:%' THEN
                            v_pass_id := substring(v_part from 4);
                            EXIT;
                        END IF;
                    END LOOP;
                ELSE
                    -- Format 2: Simple pipe format (PASS_ID|HASH|TIMESTAMP)
                    v_qr_parts := string_to_array(verification_code, '|');
                    v_pass_id := v_qr_parts[1];
                END IF;
                
                -- If we still don't have a pass ID, try to extract any UUID-like string
                IF v_pass_id IS NULL OR v_pass_id = '' THEN
                    -- Look for any UUID pattern in the string
                    v_pass_id := (regexp_matches(verification_code, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'))[1];
                END IF;
                
                RAISE NOTICE 'Extracted pass_id from legacy QR: %', v_pass_id;
            END;
        END;
    ELSE
        -- For backup codes, find pass ID by short_code
        SELECT pp.id::text
        INTO v_pass_id
        FROM purchased_passes pp
        WHERE pp.short_code = verification_code
          AND pp.status = 'active'
          AND pp.expires_at > NOW()
          AND pp.activation_date <= NOW()
        LIMIT 1;
        
        IF v_pass_id IS NULL THEN
            RAISE NOTICE 'No pass found for backup code: %', verification_code;
            RETURN; -- No valid pass found
        END IF;
        
        RAISE NOTICE 'Found pass_id for backup code: %', v_pass_id;
    END IF;
    
    -- Now query the pass with all related data using the pass ID
    RETURN QUERY
    SELECT 
        pp.id::text,
        COALESCE(pp.vehicle_description, ''),
        COALESCE(pp.pass_description, ''),
        COALESCE(b_entry.name, ''),
        COALESCE(b_exit.name, ''),
        COALESCE(pp.entry_limit, 1),
        COALESCE(pp.entries_remaining, pp.entry_limit, 1),
        pp.issued_at,
        pp.activation_date,
        pp.expires_at,
        pp.status,
        COALESCE(pp.current_status, 'unused'),
        COALESCE(pp.currency, 'USD'),
        COALESCE(pp.amount, 0.0),
        jsonb_build_object(
            'id', pp.id,
            'hash', COALESCE(pp.pass_hash, ''),
            'expires', extract(epoch from pp.expires_at)::bigint
        )::text, -- QR code as simplified format
        COALESCE(pp.short_code, ''),
        COALESCE(pp.pass_hash, ''),
        COALESCE(pp.authority_id::text, ''),
        COALESCE(a.name, ''),
        COALESCE(c.name, ''),
        COALESCE(pp.entry_point_id::text, ''),
        COALESCE(pp.exit_point_id::text, ''),
        COALESCE(pp.vehicle_registration_number, ''),
        COALESCE(pp.vehicle_vin, ''),
        COALESCE(pp.vehicle_make, ''),
        COALESCE(pp.vehicle_model, ''),
        pp.vehicle_year,
        COALESCE(pp.vehicle_color, ''),
        COALESCE(pp.secure_code, ''),
        pp.secure_code_expires_at,
        jsonb_build_object(
            'id', pp.id,
            'hash', COALESCE(pp.pass_hash, ''),
            'expires', extract(epoch from pp.expires_at)::bigint
        )
    FROM purchased_passes pp
    LEFT JOIN authorities a ON pp.authority_id = a.id
    LEFT JOIN countries c ON a.country_id = c.id
    LEFT JOIN borders b_entry ON pp.entry_point_id = b_entry.id
    LEFT JOIN borders b_exit ON pp.exit_point_id = b_exit.id
    WHERE pp.id::text = v_pass_id
      AND pp.status = 'active'
      AND pp.expires_at > NOW()
      AND pp.activation_date <= NOW();
END;
$$;

-- Function to check if current user can verify passes at a specific border
CREATE OR REPLACE FUNCTION can_verify_pass_at_border(
    p_border_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_can_access BOOLEAN := false;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- Check if user is a border official assigned to this border
    SELECT EXISTS(
        SELECT 1 FROM border_official_borders bob
        WHERE bob.profile_id = v_user_id
          AND bob.border_id = p_border_id
          AND bob.is_active = true
    ) INTO v_can_access;
    
    IF v_can_access THEN
        RETURN true;
    END IF;
    
    -- Check if user is a country admin or authority admin for this border's authority
    SELECT EXISTS(
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        JOIN borders b ON b.authority_id = pr.authority_id
        WHERE pr.profile_id = v_user_id
          AND b.id = p_border_id
          AND r.name IN ('country_admin', 'authority_admin', 'super_admin')
          AND pr.is_active = true
    ) INTO v_can_access;
    
    RETURN v_can_access;
END;
$$;

-- Function to get borders where current user can verify passes
CREATE OR REPLACE FUNCTION get_user_verification_borders()
RETURNS TABLE (
    border_id UUID,
    border_name TEXT,
    authority_name TEXT,
    country_name TEXT,
    can_check_in BOOLEAN,
    can_check_out BOOLEAN,
    border_type_label TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN;
    END IF;
    
    -- Return borders where user is assigned as border official
    RETURN QUERY
    SELECT 
        b.id as border_id,
        b.name as border_name,
        a.name as authority_name,
        c.name as country_name,
        bob.can_check_in,
        bob.can_check_out,
        bt.label as border_type_label
    FROM border_official_borders bob
    JOIN borders b ON bob.border_id = b.id
    JOIN authorities a ON b.authority_id = a.id
    JOIN countries c ON a.country_id = c.id
    LEFT JOIN border_types bt ON b.border_type_id = bt.id
    WHERE bob.profile_id = v_user_id
      AND bob.is_active = true
      AND b.is_active = true
    
    UNION
    
    -- Also include borders where user is country/authority admin
    SELECT 
        b.id as border_id,
        b.name as border_name,
        a.name as authority_name,
        c.name as country_name,
        true as can_check_in,  -- Admins have all permissions
        true as can_check_out,
        bt.label as border_type_label
    FROM borders b
    JOIN authorities a ON b.authority_id = a.id
    JOIN countries c ON a.country_id = c.id
    LEFT JOIN border_types bt ON b.border_type_id = bt.id
    WHERE EXISTS (
        SELECT 1 FROM profile_roles pr
        JOIN roles r ON pr.role_id = r.id
        WHERE pr.profile_id = v_user_id
          AND pr.authority_id = a.id
          AND r.name IN ('country_admin', 'authority_admin', 'super_admin')
          AND pr.is_active = true
    )
    AND b.is_active = true
    AND NOT EXISTS (
        -- Exclude borders already returned by border official query
        SELECT 1 FROM border_official_borders bob2
        WHERE bob2.profile_id = v_user_id
          AND bob2.border_id = b.id
          AND bob2.is_active = true
    )
    
    ORDER BY authority_name, border_name;
END;
$$;

-- Function to generate simplified QR code data for a pass
CREATE OR REPLACE FUNCTION generate_pass_qr_data(
    p_pass_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass_record RECORD;
    v_qr_data TEXT;
BEGIN
    -- Get pass information
    SELECT id, pass_hash, expires_at
    INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pass not found';
    END IF;
    
    -- Create simplified QR format: PASS_ID|HASH|EXPIRY_TIMESTAMP
    v_qr_data := v_pass_record.id::text || '|' || 
                 COALESCE(v_pass_record.pass_hash, '') || '|' ||
                 extract(epoch from v_pass_record.expires_at)::bigint::text;
    
    RETURN v_qr_data;
END;
$$;

-- Function to update pass QR data (for existing passes)
CREATE OR REPLACE FUNCTION update_pass_qr_data()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_count INTEGER := 0;
    v_pass_record RECORD;
    v_qr_data JSONB;
BEGIN
    -- Update QR data for all active passes that don't have it
    FOR v_pass_record IN 
        SELECT id, pass_hash, expires_at
        FROM purchased_passes
        WHERE status = 'active'
          AND (qr_data IS NULL OR qr_data = '{}' OR qr_data = 'null')
    LOOP
        -- Create simplified QR data structure
        v_qr_data := jsonb_build_object(
            'id', v_pass_record.id,
            'hash', COALESCE(v_pass_record.pass_hash, ''),
            'expires', extract(epoch from v_pass_record.expires_at)::bigint
        );
        
        -- Update the pass
        UPDATE purchased_passes
        SET qr_data = v_qr_data,
            updated_at = NOW()
        WHERE id = v_pass_record.id;
        
        v_updated_count := v_updated_count + 1;
    END LOOP;
    
    RETURN v_updated_count;
END;
$$;

-- ============================================================================
-- STEP 2: Grant Permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION verify_pass TO authenticated;
GRANT EXECUTE ON FUNCTION can_verify_pass_at_border TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_verification_borders TO authenticated;
GRANT EXECUTE ON FUNCTION generate_pass_qr_data TO authenticated;
GRANT EXECUTE ON FUNCTION update_pass_qr_data TO authenticated;

-- ============================================================================
-- STEP 3: Add QR Data Column if Missing
-- ============================================================================

DO $$
BEGIN
    -- Add qr_data column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'qr_data'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN qr_data JSONB DEFAULT '{}';
        COMMENT ON COLUMN purchased_passes.qr_data IS 'Simplified QR code data structure';
        RAISE NOTICE 'Added qr_data column to purchased_passes';
    END IF;
    
    -- Add short_code column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'short_code'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN short_code TEXT;
        COMMENT ON COLUMN purchased_passes.short_code IS 'Short backup code for manual entry';
        RAISE NOTICE 'Added short_code column to purchased_passes';
    END IF;
    
    -- Add pass_hash column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchased_passes' 
        AND column_name = 'pass_hash'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE purchased_passes ADD COLUMN pass_hash TEXT;
        COMMENT ON COLUMN purchased_passes.pass_hash IS 'Hash for pass verification';
        RAISE NOTICE 'Added pass_hash column to purchased_passes';
    END IF;
END $$;

-- ============================================================================
-- STEP 4: Initialize QR Data for Existing Passes
-- ============================================================================

-- Update existing passes with QR data
SELECT update_pass_qr_data() as passes_updated;

-- ============================================================================
-- STEP 5: Add Comments
-- ============================================================================

COMMENT ON FUNCTION verify_pass IS 'Verifies a pass by QR code or backup code and returns pass details';
COMMENT ON FUNCTION can_verify_pass_at_border IS 'Checks if current user can verify passes at a specific border';
COMMENT ON FUNCTION get_user_verification_borders IS 'Returns borders where current user can verify passes';
COMMENT ON FUNCTION generate_pass_qr_data IS 'Generates simplified QR code data for a pass';
COMMENT ON FUNCTION update_pass_qr_data IS 'Updates QR data for existing passes';

-- Debug function to check QR data format
CREATE OR REPLACE FUNCTION debug_qr_data()
RETURNS TABLE (
    pass_id TEXT,
    qr_data_content JSONB,
    short_code TEXT,
    pass_hash TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pp.id::text,
        pp.qr_data,
        pp.short_code,
        pp.pass_hash
    FROM purchased_passes pp
    WHERE pp.status = 'active'
    ORDER BY pp.created_at DESC
    LIMIT 5;
END;
$$;

GRANT EXECUTE ON FUNCTION debug_qr_data TO authenticated;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Pass Verification System Setup Complete!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '- Function: verify_pass (for QR scanning)';
    RAISE NOTICE '- Function: can_verify_pass_at_border (authority checking)';
    RAISE NOTICE '- Function: get_user_verification_borders (user borders)';
    RAISE NOTICE '- Function: generate_pass_qr_data (QR generation)';
    RAISE NOTICE '- Function: update_pass_qr_data (data migration)';
    RAISE NOTICE '- Columns: qr_data, short_code, pass_hash (if missing)';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'QR Code Format: PASS_ID|HASH|EXPIRY_TIMESTAMP';
    RAISE NOTICE 'The system now supports QR scanning and authority restrictions!';
    RAISE NOTICE '=================================================================';
END $$;