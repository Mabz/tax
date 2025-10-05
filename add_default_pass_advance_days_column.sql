-- Add default_pass_advance_days column to authorities table if it doesn't exist
-- This column stores the default number of days in advance that passes can be purchased

DO $$ 
BEGIN
    -- Check if the column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'authorities' 
        AND column_name = 'default_pass_advance_days'
    ) THEN
        ALTER TABLE authorities 
        ADD COLUMN default_pass_advance_days INTEGER;
        
        -- Add a comment to explain the column
        COMMENT ON COLUMN authorities.default_pass_advance_days IS 'Default number of days in advance that passes can be purchased for this authority';
        
        RAISE NOTICE 'Added default_pass_advance_days column to authorities table';
    ELSE
        RAISE NOTICE 'Column default_pass_advance_days already exists in authorities table';
    END IF;
END $$;

-- Update the RPC function to handle the new column if it exists
CREATE OR REPLACE FUNCTION update_authority(
    target_authority_id UUID,
    new_name TEXT DEFAULT NULL,
    new_code TEXT DEFAULT NULL,
    new_authority_type TEXT DEFAULT NULL,
    new_description TEXT DEFAULT NULL,
    new_default_pass_advance_days INTEGER DEFAULT NULL,
    new_default_currency_code TEXT DEFAULT NULL,
    new_is_active BOOLEAN DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update the authority with provided values
    UPDATE authorities 
    SET 
        name = COALESCE(new_name, name),
        code = COALESCE(new_code, code),
        authority_type = COALESCE(new_authority_type, authority_type),
        description = COALESCE(new_description, description),
        default_pass_advance_days = COALESCE(new_default_pass_advance_days, default_pass_advance_days),
        default_currency_code = COALESCE(new_default_currency_code, default_currency_code),
        is_active = COALESCE(new_is_active, is_active),
        updated_at = NOW()
    WHERE id = target_authority_id;
    
    -- Check if any rows were affected
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Authority with ID % not found', target_authority_id;
    END IF;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_authority TO authenticated;