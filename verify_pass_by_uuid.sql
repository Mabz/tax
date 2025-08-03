-- Updated verification function using full UUID instead of hash
-- This is more secure and reliable than using generated hash codes

-- Verify by UUID (QR scanning) - Primary verification method
CREATE OR REPLACE FUNCTION verify_pass_by_uuid(input_uuid UUID)
RETURNS TABLE(pass_data JSONB, is_valid BOOLEAN) AS $$
BEGIN
  RETURN QUERY
  SELECT qr_data, (status = 'active' AND expires_at > NOW()) as is_valid
  FROM purchased_passes 
  WHERE id = input_uuid;
END;
$$ LANGUAGE plpgsql;

-- Keep the hash verification as backup for existing passes
CREATE OR REPLACE FUNCTION verify_pass_by_hash(input_hash TEXT)
RETURNS TABLE(pass_data JSONB, is_valid BOOLEAN) AS $$
BEGIN
  RETURN QUERY
  SELECT qr_data, (status = 'active' AND expires_at > NOW()) as is_valid
  FROM purchased_passes 
  WHERE pass_hash = input_hash;
END;
$$ LANGUAGE plpgsql;

-- Verify by short code (manual entry backup)
CREATE OR REPLACE FUNCTION verify_pass_by_short_code(input_code TEXT)
RETURNS TABLE(pass_data JSONB, is_valid BOOLEAN) AS $$
BEGIN
  RETURN QUERY
  SELECT qr_data, (status = 'active' AND expires_at > NOW()) as is_valid
  FROM purchased_passes 
  WHERE short_code = input_code;
END;
$$ LANGUAGE plpgsql;
