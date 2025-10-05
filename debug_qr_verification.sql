-- Debug script to check QR data format and verification
-- This will help us understand why QR scanning fails but backup codes work

DO $$
DECLARE
    v_sample_pass_id UUID;
    v_qr_data JSONB;
    v_qr_string TEXT;
    v_short_code TEXT;
    v_verification_result RECORD;
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Debugging QR Code Verification Issue';
    RAISE NOTICE '=================================================================';
    
    -- Get a sample active pass
    SELECT id, qr_data, short_code
    INTO v_sample_pass_id, v_qr_data, v_short_code
    FROM purchased_passes 
    WHERE status = 'active' 
      AND expires_at > NOW() 
      AND activation_date <= NOW()
      AND qr_data IS NOT NULL
    LIMIT 1;
    
    IF v_sample_pass_id IS NULL THEN
        RAISE NOTICE '❌ No active passes found with QR data';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found sample pass: %', v_sample_pass_id;
    RAISE NOTICE 'Short code: %', v_short_code;
    
    -- Check QR data format
    RAISE NOTICE '';
    RAISE NOTICE '📋 QR Data Analysis:';
    RAISE NOTICE 'Type: %', pg_typeof(v_qr_data);
    RAISE NOTICE 'Length: % characters', LENGTH(v_qr_data::text);
    RAISE NOTICE 'First 100 chars: %', LEFT(v_qr_data::text, 100);
    
    -- Convert to string for verification
    v_qr_string := v_qr_data::text;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Testing QR Code Verification:';
    
    -- Test QR code verification
    BEGIN
        SELECT * INTO v_verification_result
        FROM verify_pass(v_qr_string, true)
        LIMIT 1;
        
        IF v_verification_result.pass_id IS NOT NULL THEN
            RAISE NOTICE '✅ QR verification SUCCESS: Found pass %', v_verification_result.pass_id;
        ELSE
            RAISE NOTICE '❌ QR verification FAILED: No pass returned';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ QR verification ERROR: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Testing Backup Code Verification:';
    
    -- Test backup code verification
    BEGIN
        SELECT * INTO v_verification_result
        FROM verify_pass(v_short_code, false)
        LIMIT 1;
        
        IF v_verification_result.pass_id IS NOT NULL THEN
            RAISE NOTICE '✅ Backup code verification SUCCESS: Found pass %', v_verification_result.pass_id;
        ELSE
            RAISE NOTICE '❌ Backup code verification FAILED: No pass returned';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Backup code verification ERROR: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 QR Data Structure Analysis:';
    
    -- Analyze QR data structure
    IF v_qr_data ? 'id' THEN
        RAISE NOTICE 'Has "id" field: %', v_qr_data->>'id';
    ELSE
        RAISE NOTICE 'Missing "id" field';
    END IF;
    
    IF v_qr_data ? 'pass_id' THEN
        RAISE NOTICE 'Has "pass_id" field: %', v_qr_data->>'pass_id';
    ELSE
        RAISE NOTICE 'Missing "pass_id" field';
    END IF;
    
    IF v_qr_data ? 'profile_id' THEN
        RAISE NOTICE 'Has "profile_id" field: %', v_qr_data->>'profile_id';
    ELSE
        RAISE NOTICE 'Missing "profile_id" field';
    END IF;
    
    IF v_qr_data ? 'pass_hash' THEN
        RAISE NOTICE 'Has "pass_hash" field: %', v_qr_data->>'pass_hash';
    ELSE
        RAISE NOTICE 'Missing "pass_hash" field';
    END IF;
    
    IF v_qr_data ? 'short_code' THEN
        RAISE NOTICE 'Has "short_code" field: %', v_qr_data->>'short_code';
    ELSE
        RAISE NOTICE 'Missing "short_code" field';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Debug complete. Check the output above to identify the issue.';
    RAISE NOTICE '=================================================================';
END $$;