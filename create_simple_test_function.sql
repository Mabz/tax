-- Create a very simple test function to isolate the issue

-- 1. Create a minimal test function
CREATE OR REPLACE FUNCTION public.test_simple_update(
    profile_id uuid,
    new_name text
)
RETURNS boolean AS $$
BEGIN
    UPDATE public.authority_profiles 
    SET display_name = new_name, updated_at = now()
    WHERE id = profile_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.test_simple_update(uuid, text) TO authenticated;

-- 2. Test the simple function
SELECT 
    'Simple function test' as test,
    test_simple_update(
        '558b7408-f858-4392-836b-c5b6231a78cd'::uuid,
        'Simple Test ' || now()::text
    ) as simple_result;

-- 3. Check if the update actually happened
SELECT 
    'After simple update' as test,
    id,
    display_name,
    updated_at
FROM authority_profiles 
WHERE id = '558b7408-f858-4392-836b-c5b6231a78cd';

-- 4. Now test the original function again
SELECT 
    'Original function test' as test,
    update_authority_profile(
        '558b7408-f858-4392-836b-c5b6231a78cd'::uuid,
        'Original Function Test',
        true,
        'Original function notes'
    ) as original_result;

-- 5. Check the result
SELECT 
    'After original function' as test,
    id,
    display_name,
    is_active,
    notes,
    updated_at
FROM authority_profiles 
WHERE id = '558b7408-f858-4392-836b-c5b6231a78cd';