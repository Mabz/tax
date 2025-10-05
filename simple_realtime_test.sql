-- Simple test to verify real-time updates are working
-- Run this while your Flutter app is open on the "My Passes" screen

-- Step 1: Find an active pass to test with
SELECT 
    'AVAILABLE PASSES FOR TESTING' as info,
    id,
    profile_id,
    pass_description,
    secure_code,
    secure_code_expires_at
FROM purchased_passes 
WHERE status = 'active'
ORDER BY created_at DESC
LIMIT 3;

-- Step 2: Test function to update a pass and trigger real-time notification
CREATE OR REPLACE FUNCTION test_secure_code_realtime(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_new_code TEXT;
    v_old_code TEXT;
BEGIN
    -- Get current secure code
    SELECT secure_code INTO v_old_code
    FROM purchased_passes
    WHERE id = p_pass_id;
    
    -- Generate new 3-digit secure code
    v_new_code := LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    
    -- Update the pass with new secure code
    UPDATE purchased_passes
    SET 
        secure_code = v_new_code,
        secure_code_expires_at = NOW() + INTERVAL '15 minutes',
        updated_at = NOW()
    WHERE id = p_pass_id;
    
    -- Log the change
    RAISE NOTICE 'Updated pass % secure code: % -> %', p_pass_id, v_old_code, v_new_code;
    
    RETURN jsonb_build_object(
        'success', true,
        'pass_id', p_pass_id,
        'old_secure_code', COALESCE(v_old_code, 'null'),
        'new_secure_code', v_new_code,
        'expires_at', NOW() + INTERVAL '15 minutes'
    );
END;
$;

GRANT EXECUTE ON FUNCTION test_secure_code_realtime TO authenticated;

-- Instructions
DO $
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'REAL-TIME TESTING INSTRUCTIONS';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE '1. Open your Flutter app';
    RAISE NOTICE '2. Go to "My Passes" screen and keep it open';
    RAISE NOTICE '3. Copy a pass ID from the results above';
    RAISE NOTICE '4. Run this command (replace with your pass ID):';
    RAISE NOTICE '   SELECT test_secure_code_realtime(''paste-pass-id-here'');';
    RAISE NOTICE '5. Watch your app - the secure code should update automatically';
    RAISE NOTICE '6. You should see a green notification saying "Secure code updated"';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'If it doesn''t work automatically:';
    RAISE NOTICE '- Check Flutter console for 🔄 debug messages';
    RAISE NOTICE '- Verify internet connection';
    RAISE NOTICE '- Try pulling down to refresh the passes list';
    RAISE NOTICE '=================================================================';
END $;