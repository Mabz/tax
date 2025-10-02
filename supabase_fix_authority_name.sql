-- Fix get_pass_templates_for_authority function to include authority_name
-- This resolves the "Unknown Authority" error in pass template selection

-- Drop and recreate the function with authority_name included
DROP FUNCTION IF EXISTS get_pass_templates_for_authority CASCADE;

CREATE OR REPLACE FUNCTION get_pass_templates_for_authority(target_authority_id UUID)
RETURNS TABLE (
    id UUID,
    description TEXT,
    entry_limit INTEGER,
    expiration_days INTEGER,
    pass_advance_days INTEGER,
    tax_amount DECIMAL,
    currency_code TEXT,
    is_active BOOLEAN,
    allow_user_selectable_points BOOLEAN,
    entry_point_name TEXT,
    exit_point_name TEXT,
    vehicle_type TEXT,
    authority_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.id,
        pt.description,
        pt.entry_limit,
        pt.expiration_days,
        pt.pass_advance_days,
        pt.tax_amount,
        pt.currency_code,
        pt.is_active,
        pt.allow_user_selectable_points,
        entry_border.name AS entry_point_name,
        exit_border.name AS exit_point_name,
        vt.label AS vehicle_type,
        a.name AS authority_name
    FROM pass_templates pt
    LEFT JOIN borders entry_border ON pt.entry_point_id = entry_border.id
    LEFT JOIN borders exit_border ON pt.exit_point_id = exit_border.id
    LEFT JOIN vehicle_types vt ON pt.vehicle_type_id = vt.id
    LEFT JOIN authorities a ON pt.authority_id = a.id
    WHERE pt.authority_id = target_authority_id
    ORDER BY pt.created_at DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority TO authenticated;

-- Drop existing get_borders_for_authority function if it exists (to handle return type changes)
DROP FUNCTION IF EXISTS get_borders_for_authority CASCADE;

-- Create get_borders_for_authority function for user-selectable entry/exit points
CREATE OR REPLACE FUNCTION get_borders_for_authority(target_authority_id UUID)
RETURNS TABLE (
    border_id UUID,
    border_name TEXT,
    border_type TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id AS border_id,
        b.name AS border_name,
        COALESCE(b.border_type_id::text, 'Unknown') AS border_type
    FROM borders b
    WHERE b.authority_id = target_authority_id
      AND b.is_active = true
    ORDER BY b.name;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_borders_for_authority TO authenticated;

-- Test the functions
DO $$
DECLARE
    test_authority_id UUID;
    template_count INTEGER;
    border_count INTEGER;
BEGIN
    -- Get a test authority ID
    SELECT id INTO test_authority_id FROM authorities LIMIT 1;
    
    IF test_authority_id IS NOT NULL THEN
        -- Test the pass templates function
        SELECT COUNT(*) INTO template_count 
        FROM get_pass_templates_for_authority(test_authority_id);
        
        RAISE NOTICE 'Pass templates function test: Found % templates for authority %', template_count, test_authority_id;
        
        -- Test the borders function
        SELECT COUNT(*) INTO border_count 
        FROM get_borders_for_authority(test_authority_id);
        
        RAISE NOTICE 'Borders function test: Found % borders for authority %', border_count, test_authority_id;
        
        -- Show sample results if they exist
        IF template_count > 0 THEN
            RAISE NOTICE 'Sample template result:';
            PERFORM * FROM get_pass_templates_for_authority(test_authority_id) LIMIT 1;
        END IF;
        
        IF border_count > 0 THEN
            RAISE NOTICE 'Sample border result:';
            PERFORM * FROM get_borders_for_authority(test_authority_id) LIMIT 1;
        END IF;
    ELSE
        RAISE NOTICE 'No authorities found for testing';
    END IF;
END;
$$;