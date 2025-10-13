-- Add passport document URL column to profiles table
ALTER TABLE profiles 
ADD COLUMN passport_document_url TEXT;

-- Create profile_settings_audit table for tracking changes
CREATE TABLE profile_settings_audit (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    change_type TEXT NOT NULL CHECK (change_type IN ('create', 'update', 'delete')),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    changed_by UUID REFERENCES profiles(id),
    ip_address INET,
    user_agent TEXT,
    notes TEXT
);

-- Create index for efficient querying
CREATE INDEX idx_profile_settings_audit_profile_id ON profile_settings_audit(profile_id);
CREATE INDEX idx_profile_settings_audit_changed_at ON profile_settings_audit(changed_at);
CREATE INDEX idx_profile_settings_audit_field_name ON profile_settings_audit(field_name);

-- Enable RLS on audit table
ALTER TABLE profile_settings_audit ENABLE ROW LEVEL SECURITY;

-- RLS policies for profile_settings_audit
-- Users can only see their own audit records
CREATE POLICY "Users can view their own audit records" ON profile_settings_audit
    FOR SELECT USING (profile_id = auth.uid());

-- Only the system can insert audit records (via functions)
CREATE POLICY "System can insert audit records" ON profile_settings_audit
    FOR INSERT WITH CHECK (true);

-- Authority users can view audit records for profiles in their authority
CREATE POLICY "Authority users can view audit records in their authority" ON profile_settings_audit
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM authority_profiles ap
            WHERE ap.profile_id = auth.uid()
            AND ap.active_status = true
            AND EXISTS (
                SELECT 1 FROM authority_profiles ap2
                WHERE ap2.profile_id = profile_settings_audit.profile_id
                AND ap2.authority_id = ap.authority_id
                AND ap2.active_status = true
            )
        )
    );

-- Function to log profile changes
CREATE OR REPLACE FUNCTION log_profile_change(
    p_profile_id UUID,
    p_field_name TEXT,
    p_old_value TEXT,
    p_new_value TEXT,
    p_change_type TEXT DEFAULT 'update',
    p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile_settings_audit (
        profile_id,
        field_name,
        old_value,
        new_value,
        change_type,
        changed_by,
        notes
    ) VALUES (
        p_profile_id,
        p_field_name,
        p_old_value,
        p_new_value,
        p_change_type,
        auth.uid(),
        p_notes
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the update_personal_information function to include audit logging
CREATE OR REPLACE FUNCTION update_personal_information(
    new_full_name TEXT,
    new_email TEXT,
    new_phone_number TEXT DEFAULT NULL,
    new_address TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    current_profile RECORD;
BEGIN
    -- Get current values for audit logging
    SELECT full_name, email, phone_number, address
    INTO current_profile
    FROM profiles
    WHERE id = auth.uid();

    -- Log changes for each field that's different
    IF current_profile.full_name IS DISTINCT FROM new_full_name THEN
        PERFORM log_profile_change(
            auth.uid(),
            'full_name',
            current_profile.full_name,
            new_full_name,
            'update'
        );
    END IF;

    IF current_profile.email IS DISTINCT FROM new_email THEN
        PERFORM log_profile_change(
            auth.uid(),
            'email',
            current_profile.email,
            new_email,
            'update'
        );
    END IF;

    IF current_profile.phone_number IS DISTINCT FROM new_phone_number THEN
        PERFORM log_profile_change(
            auth.uid(),
            'phone_number',
            current_profile.phone_number,
            new_phone_number,
            'update'
        );
    END IF;

    IF current_profile.address IS DISTINCT FROM new_address THEN
        PERFORM log_profile_change(
            auth.uid(),
            'address',
            current_profile.address,
            new_address,
            'update'
        );
    END IF;

    -- Update the profile
    UPDATE profiles
    SET 
        full_name = new_full_name,
        email = new_email,
        phone_number = new_phone_number,
        address = new_address,
        updated_at = NOW()
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update passport document URL
CREATE OR REPLACE FUNCTION update_passport_document_url(
    new_passport_document_url TEXT
) RETURNS VOID AS $$
DECLARE
    current_url TEXT;
BEGIN
    -- Get current passport document URL for audit logging
    SELECT passport_document_url
    INTO current_url
    FROM profiles
    WHERE id = auth.uid();

    -- Log the change
    PERFORM log_profile_change(
        auth.uid(),
        'passport_document_url',
        current_url,
        new_passport_document_url,
        'update',
        'Passport document uploaded'
    );

    -- Update the passport document URL
    UPDATE profiles
    SET 
        passport_document_url = new_passport_document_url,
        updated_at = NOW()
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to remove passport document
CREATE OR REPLACE FUNCTION remove_passport_document() RETURNS VOID AS $$
DECLARE
    current_url TEXT;
BEGIN
    -- Get current passport document URL for audit logging
    SELECT passport_document_url
    INTO current_url
    FROM profiles
    WHERE id = auth.uid();

    -- Log the change
    PERFORM log_profile_change(
        auth.uid(),
        'passport_document_url',
        current_url,
        NULL,
        'delete',
        'Passport document removed'
    );

    -- Remove the passport document URL
    UPDATE profiles
    SET 
        passport_document_url = NULL,
        updated_at = NOW()
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get profile audit history
CREATE OR REPLACE FUNCTION get_profile_audit_history(
    p_profile_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
) RETURNS TABLE (
    id UUID,
    field_name TEXT,
    old_value TEXT,
    new_value TEXT,
    change_type TEXT,
    changed_at TIMESTAMP WITH TIME ZONE,
    changed_by_name TEXT,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        psa.id,
        psa.field_name,
        psa.old_value,
        psa.new_value,
        psa.change_type,
        psa.changed_at,
        COALESCE(p.full_name, 'System') as changed_by_name,
        psa.notes
    FROM profile_settings_audit psa
    LEFT JOIN profiles p ON p.id = psa.changed_by
    WHERE psa.profile_id = COALESCE(p_profile_id, auth.uid())
    ORDER BY psa.changed_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update identity documents function to include audit logging
CREATE OR REPLACE FUNCTION update_identity_documents(
    new_country_of_origin_id TEXT,
    new_national_id_number TEXT,
    new_passport_number TEXT
) RETURNS VOID AS $$
DECLARE
    current_profile RECORD;
BEGIN
    -- Get current values for audit logging
    SELECT country_of_origin_id, national_id_number, passport_number
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
        country_of_origin_id = new_country_of_origin_id::UUID,
        national_id_number = new_national_id_number,
        passport_number = new_passport_number,
        updated_at = NOW()
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;