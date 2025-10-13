-- Debug: Check passport documents in the database

-- 1. Check if passport_document_url column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name = 'passport_document_url';

-- 2. Check how many profiles have passport documents
SELECT 
    COUNT(*) as total_profiles,
    COUNT(passport_document_url) as profiles_with_passport_url,
    COUNT(CASE WHEN passport_document_url IS NOT NULL AND passport_document_url != '' THEN 1 END) as profiles_with_valid_passport_url
FROM profiles;

-- 3. Show sample passport document URLs (first 5)
SELECT 
    id,
    full_name,
    passport_number,
    passport_document_url,
    CASE 
        WHEN passport_document_url IS NULL THEN 'NULL'
        WHEN passport_document_url = '' THEN 'EMPTY STRING'
        WHEN LENGTH(passport_document_url) > 0 THEN 'HAS URL'
        ELSE 'UNKNOWN'
    END as url_status
FROM profiles 
WHERE passport_document_url IS NOT NULL OR passport_number IS NOT NULL
ORDER BY updated_at DESC
LIMIT 10;

-- 4. Check if there are any profiles that might be vehicle owners
SELECT DISTINCT
    p.id,
    p.full_name,
    p.email,
    p.passport_document_url,
    COUNT(pp.id) as pass_count
FROM profiles p
LEFT JOIN purchased_passes pp ON pp.profile_id = p.id
GROUP BY p.id, p.full_name, p.email, p.passport_document_url
HAVING COUNT(pp.id) > 0
ORDER BY pass_count DESC
LIMIT 5;

-- 5. Test the get_owner_profile_for_authority function with a sample profile
-- (This will only work if you're logged in as an authority user)
-- SELECT * FROM get_owner_profile_for_authority('SAMPLE_UUID_HERE');