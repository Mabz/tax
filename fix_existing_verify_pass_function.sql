-- Fix the existing verify_pass function to include location validation
-- This updates the current function that returns all pass fields

-- First, create the helper function to determine vehicle location status
CREATE OR REPLACE FUNCTION get_vehicle_location_status(p_pass_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_latest_movement RECORD;
    v_pass_status TEXT;
BEGIN
    -- Get the latest movement
    SELECT 
        movement_type,
        new_status,
        processed_at
    INTO v_latest_movement
    FROM pass_movements
    WHERE pass_id = p_pass_id
    ORDER BY processed_at DESC
    LIMIT 1;

    -- Get current pass status
    SELECT current_status INTO v_pass_status
    FROM purchased_passes
    WHERE id = p_pass_id;

    -- Determine location status based on latest movement
    IF v_latest_movement.movement_type = 'check_out' THEN
        RETURN 'departed';
    ELSIF v_latest_movement.movement_type = 'check_in' THEN
        RETURN 'in_country';
    ELSIF v_pass_status IN ('active', 'unused') THEN
        RETURN 'in_country'; -- Default for active passes without movements
    ELSE
        RETURN 'unknown';
    END IF;
END;
$$;

-- Drop the existing function first, then recreate with new return type
DROP FUNCTION IF EXISTS verify_pass(TEXT, BOOLEAN);

-- Now create the enhanced verify_pass function with validation logic
CREATE OR REPLACE FUNCTION verify_pass(
    verification_code TEXT,
    is_qr_code BOOLEAN
)
RETURNS TABLE (
    pass_id UUID,
    profile_id UUID,
    vehicle_id UUID,
    pass_template_id UUID,
    authority_id UUID,
    country_id UUID,
    entry_point_id UUID,
    exit_point_id UUID,
    pass_description TEXT,
    vehicle_description TEXT,
    vehicle_vin TEXT,
    entry_limit INTEGER,
    entries_remaining INTEGER,
    issued_at TIMESTAMPTZ,
    activation_date TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    status TEXT,
    current_status TEXT,
    currency TEXT,
    amount DECIMAL,
    qr_data JSONB,
    short_code TEXT,
    pass_hash TEXT,
    secure_code TEXT,
    secure_code_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    vehicle_make TEXT,
    vehicle_model TEXT,
    vehicle_year INTEGER,
    vehicle_color TEXT,
    vehicle_registration_number TEXT,
    authority_name TEXT,
    country_name TEXT,
    entry_point_name TEXT,
    exit_point_name TEXT,
    -- New fields for validation logic
    vehicle_location_status TEXT,
    is_legal_for_local_authority BOOLEAN,
    violation_reason TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass_id UUID;
    v_vehicle_location_status TEXT;
    v_is_legal BOOLEAN := false;
    v_violation_reason TEXT;
    v_pass_record RECORD;
BEGIN
    -- Log the verification attempt
    RAISE NOTICE 'verify_pass called with code: %, is_qr: %', 
        SUBSTRING(verification_code, 1, 20), is_qr_code;

    -- Step 1: Extract pass ID from the verification code
    IF is_qr_code THEN
        -- Try to parse as JSON first
        BEGIN
            v_pass_id := (verification_code::jsonb->>'id')::UUID;
            RAISE NOTICE 'Extracted pass ID from JSON: %', v_pass_id;
        EXCEPTION WHEN OTHERS THEN
            -- If not JSON, try as plain UUID
            BEGIN
                v_pass_id := verification_code::UUID;
                RAISE NOTICE 'Using code as plain UUID: %', v_pass_id;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Failed to parse QR code as UUID';
                RETURN;
            END;
        END;
    ELSE
        -- Backup code - look up by short_code
        SELECT pp.id INTO v_pass_id
        FROM purchased_passes pp
        WHERE pp.short_code = verification_code
           OR pp.short_code = REPLACE(verification_code, '-', '')
           OR pp.pass_hash = verification_code
           OR pp.pass_hash = REPLACE(verification_code, '-', '');
        
        IF v_pass_id IS NULL THEN
            RAISE NOTICE 'No pass found for backup code: %', verification_code;
            RETURN;
        END IF;
        
        RAISE NOTICE 'Found pass by backup code: %', v_pass_id;
    END IF;

    -- Step 2: Get pass details
    SELECT * INTO v_pass_record
    FROM purchased_passes
    WHERE id = v_pass_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Pass not found in database: %', v_pass_id;
        RETURN;
    END IF;

    -- Step 3: Determine vehicle location status
    v_vehicle_location_status := get_vehicle_location_status(v_pass_id);

    -- Step 4: Apply validation logic for local authority scans
    IF v_vehicle_location_status = 'departed' THEN
        v_is_legal := false;
        v_violation_reason := 'Vehicle shows as departed but found in country - possible illegal re-entry or data error';
        
    ELSIF v_pass_record.status = 'expired' THEN
        v_is_legal := false;
        v_violation_reason := 'Pass has expired';
        
    ELSIF v_pass_record.entries_remaining <= 0 AND v_pass_record.current_status != 'checked_in' THEN
        v_is_legal := false;
        v_violation_reason := 'No entries remaining on pass';
        
    ELSIF v_pass_record.expires_at < NOW() THEN
        v_is_legal := false;
        v_violation_reason := 'Pass validity period has expired';
        
    ELSIF v_pass_record.status = 'cancelled' THEN
        v_is_legal := false;
        v_violation_reason := 'Pass has been cancelled';
        
    ELSE
        v_is_legal := true;
        v_violation_reason := null;
    END IF;

    -- Step 5: Return the pass details with validation results
    RETURN QUERY
    SELECT 
        v_pass_record.id,
        v_pass_record.profile_id,
        v_pass_record.vehicle_id,
        v_pass_record.pass_template_id,
        v_pass_record.authority_id,
        v_pass_record.country_id,
        v_pass_record.entry_point_id,
        v_pass_record.exit_point_id,
        v_pass_record.pass_description,
        v_pass_record.vehicle_description,
        v_pass_record.vehicle_vin,
        v_pass_record.entry_limit,
        v_pass_record.entries_remaining,
        v_pass_record.issued_at,
        v_pass_record.activation_date,
        v_pass_record.expires_at,
        v_pass_record.status,
        v_pass_record.current_status,
        v_pass_record.currency,
        v_pass_record.amount,
        v_pass_record.qr_data,
        v_pass_record.short_code,
        v_pass_record.pass_hash,
        v_pass_record.secure_code,
        v_pass_record.secure_code_expires_at,
        v_pass_record.created_at,
        v_pass_record.updated_at,
        v_pass_record.vehicle_make,
        v_pass_record.vehicle_model,
        v_pass_record.vehicle_year,
        v_pass_record.vehicle_color,
        v_pass_record.vehicle_registration_number,
        v_pass_record.authority_name,
        v_pass_record.country_name,
        v_pass_record.entry_point_name,
        v_pass_record.exit_point_name,
        -- New validation fields
        v_vehicle_location_status,
        v_is_legal,
        v_violation_reason;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_vehicle_location_status TO authenticated;
GRANT EXECUTE ON FUNCTION verify_pass(TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_pass(TEXT, BOOLEAN) TO anon;

-- Add comments
COMMENT ON FUNCTION get_vehicle_location_status IS 'Determines if vehicle is in_country, departed, or unknown based on movement history';
COMMENT ON FUNCTION verify_pass IS 'Enhanced pass verification with location-aware validation logic - now includes vehicle_location_status, is_legal_for_local_authority, and violation_reason fields';

-- Test message
SELECT '✅ Enhanced verify_pass function updated with location validation' as status;
SELECT 'The function now returns 3 additional fields: vehicle_location_status, is_legal_for_local_authority, violation_reason' as info;