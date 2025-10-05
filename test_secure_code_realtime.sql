-- Test secure code real-time functionality
-- This script helps test if secure codes are generated and updated in real-time

-- Function to manually generate a secure code for testing
CREATE OR REPLACE FUNCTION manual_generate_secure_code(
    p_pass_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_result JSONB;
BEGIN
    -- Generate secure code with 15-minute expiry
    SELECT generate_secure_code_for_pass(p_pass_id, 15) INTO v_result;
    
    -- Log the result for debugging
    RAISE NOTICE 'Generated secure code for pass %: %', p_pass_id, v_result;
    
    RETURN v_result;
END;
$;

-- Function to check current secure codes
CREATE OR REPLACE FUNCTION check_secure_codes()
RETURNS TABLE (
    pass_id UUID,
    secure_code TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    minutes_remaining INTEGER,
    is_expired BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
    RETURN QUERY
    SELECT 
        pp.id,
        pp.secure_code,
        pp.secure_code_expires_at,
        CASE 
            WHEN pp.secure_code_expires_at IS NOT NULL THEN
                GREATEST(0, EXTRACT(EPOCH FROM (pp.secure_code_expires_at - NOW())) / 60)::INTEGER
            ELSE 0
        END as minutes_remaining,
        CASE 
            WHEN pp.secure_code_expires_at IS NOT NULL THEN
                pp.secure_code_expires_at <= NOW()
            ELSE true
        END as is_expired
    FROM purchased_passes pp
    WHERE pp.secure_code IS NOT NULL
    ORDER BY pp.secure_code_expires_at DESC NULLS LAST;
END;
$;

-- Function to simulate border control processing (for testing)
CREATE OR REPLACE FUNCTION simulate_border_processing(
    p_pass_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_border_id UUID;
    v_result JSONB;
BEGIN
    -- Get any border for testing
    SELECT id INTO v_border_id FROM borders LIMIT 1;
    
    IF v_border_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No borders found for testing'
        );
    END IF;
    
    -- Process the pass movement (this should generate a secure code)
    SELECT process_pass_movement(
        p_pass_id,
        v_border_id,
        NULL, -- latitude
        NULL, -- longitude
        jsonb_build_object('test', true, 'simulated', true)
    ) INTO v_result;
    
    RETURN v_result;
END;
$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION manual_generate_secure_code TO authenticated;
GRANT EXECUTE ON FUNCTION check_secure_codes TO authenticated;
GRANT EXECUTE ON FUNCTION simulate_border_processing TO authenticated;

-- Test instructions
DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Secure Code Testing Functions Created!';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'To test secure code functionality:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Check current secure codes:';
    RAISE NOTICE '   SELECT * FROM check_secure_codes();';
    RAISE NOTICE '';
    RAISE NOTICE '2. Generate a secure code manually:';
    RAISE NOTICE '   SELECT manual_generate_secure_code(''your-pass-id-here'');';
    RAISE NOTICE '';
    RAISE NOTICE '3. Simulate border processing:';
    RAISE NOTICE '   SELECT simulate_border_processing(''your-pass-id-here'');';
    RAISE NOTICE '';
    RAISE NOTICE '4. Test the complete functionality:';
    RAISE NOTICE '   SELECT test_secure_code_functionality();';
    RAISE NOTICE '=================================================================';
END $;