-- Create function to update movement record with scan purpose and notes
-- Run this in your Supabase SQL editor

-- Function to update an existing movement record with scan purpose and notes
CREATE OR REPLACE FUNCTION update_movement_record(
    p_movement_id UUID,
    p_scan_purpose TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_count INTEGER;
    v_result JSONB;
BEGIN
    -- Update the movement record with scan_purpose in the main column
    UPDATE pass_movements 
    SET 
        notes = COALESCE(p_notes, notes), -- Keep existing notes if new ones are null
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'updated_at', NOW(),
            'status', 'completed',
            'authority_type', 'local_authority',
            'scan_purpose', p_scan_purpose  -- Also keep in metadata for reference
        )
    WHERE id = p_movement_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Movement record not found: %', p_movement_id;
    END IF;
    
    -- Return success info
    v_result := jsonb_build_object(
        'success', true,
        'movement_id', p_movement_id,
        'scan_purpose', p_scan_purpose,
        'notes', p_notes,
        'updated_at', NOW()
    );
    
    RETURN v_result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_movement_record TO authenticated;
GRANT EXECUTE ON FUNCTION update_movement_record TO anon;

-- Add comment
COMMENT ON FUNCTION update_movement_record IS 'Updates an existing movement record with scan purpose and notes';

SELECT 'update_movement_record function created successfully' as status;