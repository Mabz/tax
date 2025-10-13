-- Fix storage RLS policies for passport uploads
-- Check if storage bucket policies exist and update them

-- First, ensure the bucket exists and has proper policies
INSERT INTO storage.buckets (id, name, public)
VALUES ('BorderTax', 'BorderTax', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Users can upload their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
DROP POLICY IF EXISTS "Public can view files" ON storage.objects;

-- Create comprehensive storage policies
CREATE POLICY "Users can upload their own files" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'BorderTax' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view their own files" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'BorderTax' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete their own files" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'BorderTax' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Public can view files" ON storage.objects
    FOR SELECT USING (bucket_id = 'BorderTax');

-- Fix duplicate update_identity_documents function
-- Drop all versions of the function first
DROP FUNCTION IF EXISTS update_identity_documents(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS update_identity_documents(UUID, TEXT, TEXT);

-- Create the correct version with audit logging
CREATE OR REPLACE FUNCTION update_identity_documents(
    new_country_of_origin_id TEXT,
    new_national_id_number TEXT,
    new_passport_number TEXT
) RETURNS VOID AS $$
DECLARE
    current_profile RECORD;
    country_uuid UUID;
BEGIN
    -- Convert country ID to UUID
    country_uuid := new_country_of_origin_id::UUID;
    
    -- Get current values for audit logging
    SELECT country_of_origin_id::TEXT, national_id_number, passport_number
    INTO current_profile
    FROM profiles
    WHERE id = auth.uid();

    -- Log changes for each field that's different
    IF current_profile.country_of_origin_id IS DISTINCT FROM new_country_of_origin_id THEN
        PERFORM log_profile_change(
            auth.uid(),
            'country_of_origin_id',
            current_profile.country_of_origin_id,
            new_country_of_origin_id,
            'update'
        );
    END IF;

    IF current_profile.national_id_number IS DISTINCT FROM new_national_id_number THEN
        PERFORM log_profile_change(
            auth.uid(),
            'national_id_number',
            current_profile.national_id_number,
            new_national_id_number,
            'update'
        );
    END IF;

    IF current_profile.passport_number IS DISTINCT FROM new_passport_number THEN
        PERFORM log_profile_change(
            auth.uid(),
            'passport_number',
            current_profile.passport_number,
            new_passport_number,
            'update'
        );
    END IF;

    -- Update the profile
    UPDATE profiles
    SET 
        country_of_origin_id = country_uuid,
        national_id_number = new_national_id_number,
        passport_number = new_passport_number,
        updated_at = NOW()
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;