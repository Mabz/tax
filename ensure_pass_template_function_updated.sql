-- Ensure the pass template function is updated with proper border name joins
-- Run this in Supabase SQL Editor

-- Drop and recreate the function to ensure it's up to date
DROP FUNCTION IF EXISTS get_pass_templates_for_authority(UUID);

CREATE OR REPLACE FUNCTION get_pass_templates_for_authority(
    target_authority_id UUID
)
RETURNS TABLE (
    id UUID,
    description TEXT,
    entry_limit INTEGER,
    expiration_days INTEGER,
    pass_advance_days INTEGER,
    tax_amount NUMERIC,
    currency_code TEXT,
    is_active BOOLEAN,
    allow_user_selectable_entry_point BOOLEAN,
    allow_user_selectable_exit_point BOOLEAN,
    entry_point_id UUID,
    exit_point_id UUID,
    entry_point_name TEXT,
    exit_point_name TEXT,
    vehicle_type TEXT,
    vehicle_type_id UUID,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
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
        pt.currency_code::TEXT,
        pt.is_active,
        COALESCE(pt.allow_user_selectable_entry_point, false) as allow_user_selectable_entry_point,
        COALESCE(pt.allow_user_selectable_exit_point, false) as allow_user_selectable_exit_point,
        pt.entry_point_id,
        pt.exit_point_id,
        CASE 
            WHEN pt.entry_point_id IS NULL THEN 'Any Entry Point'
            ELSE COALESCE(entry_border.name, 'Unknown Entry Point')
        END as entry_point_name,
        CASE 
            WHEN pt.exit_point_id IS NULL THEN 'Any Exit Point'
            ELSE COALESCE(exit_border.name, 'Unknown Exit Point')
        END as exit_point_name,
        COALESCE(vt.label, 'Unknown Vehicle Type') as vehicle_type,
        pt.vehicle_type_id,
        pt.created_at,
        pt.updated_at
    FROM pass_templates pt
    LEFT JOIN borders entry_border ON pt.entry_point_id = entry_border.id
    LEFT JOIN borders exit_border ON pt.exit_point_id = exit_border.id
    LEFT JOIN vehicle_types vt ON pt.vehicle_type_id = vt.id
    WHERE pt.authority_id = target_authority_id
    ORDER BY pt.created_at DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_pass_templates_for_authority TO authenticated;

-- Test the function to see what it returns
-- SELECT id, entry_point_id, entry_point_name, exit_point_id, exit_point_name 
-- FROM get_pass_templates_for_authority('your-authority-id-here') 
-- LIMIT 3;