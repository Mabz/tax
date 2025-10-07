-- Create the verify_pass function that the app is calling
-- This function validates a pass by QR code or backup code

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS verify_pass(TEXT, BOOLEAN);

-- Create the verify_pass function
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
    exit_point_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass_id UUID;
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

    -- Step 2: Return the pass details
    RETURN QUERY
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
        pp.vehicle_vin,
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
        pp.vehicle_make,
        pp.vehicle_model,
        pp.vehicle_year,
        pp.vehicle_color,
        pp.vehicle_registration_number,
        pp.authority_name,
        pp.country_name,
        pp.entry_point_name,
        pp.exit_point_name
    FROM purchased_passes pp
    WHERE pp.id = v_pass_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Pass not found in database: %', v_pass_id;
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION verify_pass(TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_pass(TEXT, BOOLEAN) TO anon;

-- Add comment
COMMENT ON FUNCTION verify_pass IS 'Verifies a pass by QR code (JSON with id) or backup code (short_code/pass_hash). Used by both Local Authority and Border Control.';

-- Test the function
DO $$
BEGIN
    RAISE NOTICE '✅ verify_pass function created successfully';
    RAISE NOTICE '   - Handles QR codes (JSON format or plain UUID)';
    RAISE NOTICE '   - Handles backup codes (short_code or pass_hash)';
    RAISE NOTICE '   - Returns full pass details for validation';
END $$;
