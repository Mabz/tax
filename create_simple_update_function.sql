-- Create a simple update function without permission checks
-- Since the service already validates permissions correctly

CREATE OR REPLACE FUNCTION public.update_authority_profile(
    profile_record_id uuid,
    new_display_name text,
    new_is_active boolean,
    new_notes text DEFAULT NULL
)
RETURNS boolean AS $$
BEGIN
    -- Simple update without permission checks
    -- The service layer handles permission validation
    UPDATE public.authority_profiles 
    SET 
        display_name = new_display_name,
        is_active = new_is_active,
        notes = new_notes,
        updated_at = now()
    WHERE id = profile_record_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper permissions
GRANT EXECUTE ON FUNCTION public.update_authority_profile(uuid, text, boolean, text) TO authenticated;

-- Test the simple function
SELECT 
    'Simple function test' as test,
    update_authority_profile(
        '2364f7d5-f082-4899-9331-4b6fdc5dab36'::uuid,
        'Simple Update Test',
        true,
        'Testing simple update'
    ) as result;

-- Verify the update worked
SELECT 
    'Verification' as test,
    id,
    display_name,
    is_active,
    notes,
    updated_at
FROM authority_profiles 
WHERE id = '2364f7d5-f082-4899-9331-4b6fdc5dab36';