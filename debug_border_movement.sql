-- Debug version of process_pass_movement to identify null value issues
-- Run this in your Supabase SQL editor

-- Create a debug version that logs what's happening
CREATE OR REPLACE FUNCTION debug_process_pass_movement(
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
    v_pass_record RECORD;
    v_debug_info JSONB;
BEGIN
    -- Get pass details and debug what we find
    SELECT * INTO v_pass_record
    FROM purchased_passes
    WHERE id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pass not found',
            'debug', 'No pass record found for ID: ' || p_pass_id::text
        );
    END IF;

    -- Build debug info about the pass record
    v_debug_info := jsonb_build_object(
        'pass_id', COALESCE(v_pass_record.id::text, 'NULL'),
        'current_status', COALESCE(v_pass_record.current_status, 'NULL'),
        'entries_remaining', COALESCE(v_pass_record.entries_remaining, -1),
        'vehicle_description', COALESCE(v_pass_record.vehicle_description, 'NULL'),
        'pass_description', COALESCE(v_pass_record.pass_description, 'NULL')
    );

    -- Return debug information
    RETURN jsonb_build_object(
        'success', true,
        'debug', 'Pass record found',
        'pass_data', v_debug_info,
        'raw_record', to_jsonb(v_pass_record)
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION debug_process_pass_movement TO authenticated;

SELECT 'Debug function created - call debug_process_pass_movement to see pass data structure' as status;