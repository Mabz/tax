-- Create all missing verification functions needed by the app
-- These functions support the pass verification flow

-- ============================================================================
-- 1. get_pass_verification_method
-- Returns the verification method preference for a pass owner
-- ============================================================================
DROP FUNCTION IF EXISTS get_pass_verification_method(UUID);

CREATE OR REPLACE FUNCTION get_pass_verification_method(
    target_pass_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_id UUID;
    v_method TEXT;
BEGIN
    -- Get the profile ID from the pass
    SELECT profile_id INTO v_profile_id
    FROM purchased_passes
    WHERE id = target_pass_id;

    IF v_profile_id IS NULL THEN
        RETURN 'none';
    END IF;

    -- Get the verification method from user_profiles
    SELECT verification_method INTO v_method
    FROM user_profiles
    WHERE id = v_profile_id;

    -- Return the method or 'none' if not set
    RETURN COALESCE(v_method, 'none');
END;
$$;

GRANT EXECUTE ON FUNCTION get_pass_verification_method(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pass_verification_method(UUID) TO anon;

-- ============================================================================
-- 2. verify_pass_pin
-- Verifies a PIN for a pass
-- ============================================================================
DROP FUNCTION IF EXISTS verify_pass_pin(UUID, TEXT);

CREATE OR REPLACE FUNCTION verify_pass_pin(
    target_pass_id UUID,
    provided_pin TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_id UUID;
    v_stored_pin TEXT;
BEGIN
    -- Get the profile ID from the pass
    SELECT profile_id INTO v_profile_id
    FROM purchased_passes
    WHERE id = target_pass_id;

    IF v_profile_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Get the stored PIN from user_profiles
    SELECT verification_pin INTO v_stored_pin
    FROM user_profiles
    WHERE id = v_profile_id;

    -- Compare PINs
    RETURN v_stored_pin IS NOT NULL AND v_stored_pin = provided_pin;
END;
$$;

GRANT EXECUTE ON FUNCTION verify_pass_pin(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_pass_pin(UUID, TEXT) TO anon;

-- ============================================================================
-- 3. verify_secure_code
-- Verifies a secure code for a pass
-- ============================================================================
DROP FUNCTION IF EXISTS verify_secure_code(UUID, TEXT);

CREATE OR REPLACE FUNCTION verify_secure_code(
    target_pass_id UUID,
    provided_code TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_secure_code TEXT;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- Get the secure code and expiry from the pass
    SELECT secure_code, secure_code_expires_at
    INTO v_secure_code, v_expires_at
    FROM purchased_passes
    WHERE id = target_pass_id;

    -- Check if secure code exists, matches, and hasn't expired
    IF v_secure_code IS NULL THEN
        RETURN FALSE;
    END IF;

    IF v_secure_code != provided_code THEN
        RETURN FALSE;
    END IF;

    IF v_expires_at IS NULL OR v_expires_at < NOW() THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION verify_secure_code(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_secure_code(UUID, TEXT) TO anon;

-- ============================================================================
-- 4. generate_secure_code_for_pass
-- Generates a temporary secure code for pass verification
-- ============================================================================
DROP FUNCTION IF EXISTS generate_secure_code_for_pass(UUID, INTEGER, UUID, DECIMAL, DECIMAL);

CREATE OR REPLACE FUNCTION generate_secure_code_for_pass(
    p_pass_id UUID,
    p_expiry_minutes INTEGER DEFAULT 15,
    p_border_id UUID DEFAULT NULL,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_secure_code TEXT;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- Generate a 3-digit secure code
    v_secure_code := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    v_expires_at := NOW() + (p_expiry_minutes || ' minutes')::INTERVAL;

    -- Update the pass with the secure code
    UPDATE purchased_passes
    SET 
        secure_code = v_secure_code,
        secure_code_expires_at = v_expires_at,
        updated_at = NOW()
    WHERE id = p_pass_id;

    -- Log the secure code generation as a verification scan
    INSERT INTO pass_movements (
        pass_id,
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
        'verification_scan',
        'unknown',
        'unknown',
        0,
        p_latitude,
        p_longitude,
        jsonb_build_object(
            'action', 'secure_code_generated',
            'expiry_minutes', p_expiry_minutes,
            'border_id', p_border_id
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'secure_code', v_secure_code,
        'expires_at', v_expires_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION generate_secure_code_for_pass(UUID, INTEGER, UUID, DECIMAL, DECIMAL) TO authenticated;

-- ============================================================================
-- 5. deduct_pass_entry
-- Deducts an entry from a pass (used by border control)
-- ============================================================================
DROP FUNCTION IF EXISTS deduct_pass_entry(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION deduct_pass_entry(
    target_pass_id UUID,
    authority_type TEXT,
    verification_data TEXT DEFAULT NULL
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
BEGIN
    -- Deduct one entry
    UPDATE purchased_passes
    SET 
        entries_remaining = GREATEST(entries_remaining - 1, 0),
        updated_at = NOW()
    WHERE id = target_pass_id
      AND entries_remaining > 0;

    -- Return the updated pass
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
    WHERE pp.id = target_pass_id;
END;
$$;

GRANT EXECUTE ON FUNCTION deduct_pass_entry(UUID, TEXT, TEXT) TO authenticated;

-- ============================================================================
-- 6. log_validation_activity
-- Logs validation activity (optional - for audit trail)
-- ============================================================================
DROP FUNCTION IF EXISTS log_validation_activity(UUID, TEXT, TEXT, BOOLEAN, TEXT);

CREATE OR REPLACE FUNCTION log_validation_activity(
    target_pass_id UUID,
    authority_type TEXT,
    action_type TEXT,
    success BOOLEAN DEFAULT TRUE,
    notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Log to pass_movements table
    INSERT INTO pass_movements (
        pass_id,
        movement_type,
        previous_status,
        new_status,
        entries_deducted,
        notes,
        metadata,
        processed_at
    ) VALUES (
        target_pass_id,
        'validation_activity',
        'unknown',
        'unknown',
        0,
        notes,
        jsonb_build_object(
            'authority_type', authority_type,
            'action_type', action_type,
            'success', success
        ),
        NOW()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION log_validation_activity(UUID, TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ All verification functions created successfully:';
    RAISE NOTICE '   1. get_pass_verification_method - Get user verification preference';
    RAISE NOTICE '   2. verify_pass_pin - Verify PIN code';
    RAISE NOTICE '   3. verify_secure_code - Verify temporary secure code';
    RAISE NOTICE '   4. generate_secure_code_for_pass - Generate secure code';
    RAISE NOTICE '   5. deduct_pass_entry - Deduct entry from pass';
    RAISE NOTICE '   6. log_validation_activity - Log validation events';
END $$;
