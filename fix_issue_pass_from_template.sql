-- Fix the issue_pass_from_template function to properly set expires_at and entries_remaining
-- These fields should be calculated from the pass template's expirationDays and entryLimit

CREATE OR REPLACE FUNCTION issue_pass_from_template(
  target_profile_id uuid,
  target_vehicle_id uuid,
  pass_template_id uuid,
  pass_hash text,
  short_code text,
  qr_data jsonb
)
RETURNS TABLE(pass_uuid uuid, authority_id uuid) AS $$
DECLARE
  new_pass_id uuid;
  template_authority_id uuid;
  template_expiration_days int;
  template_entry_limit int;
  calculated_expires_at timestamptz;
  updated_qr_data jsonb;
BEGIN
  -- Get the authority, expiration days, and entry limit from the pass template
  SELECT pt.authority_id, pt.expiration_days, pt.entry_limit
  INTO template_authority_id, template_expiration_days, template_entry_limit
  FROM pass_templates pt
  WHERE pt.id = pass_template_id;
  
  IF template_authority_id IS NULL THEN
    RAISE EXCEPTION 'Pass template not found or has no authority';
  END IF;
  
  -- Calculate the expiration date
  calculated_expires_at := NOW() + INTERVAL '1 day' * template_expiration_days;
  
  -- Insert the pass with properly calculated fields
  INSERT INTO purchased_passes (
    profile_id,
    vehicle_id,
    pass_template_id,
    authority_id,
    pass_hash,
    short_code,
    qr_data,
    status,
    expires_at,
    entries_remaining
  ) VALUES (
    target_profile_id,
    target_vehicle_id,
    pass_template_id,
    template_authority_id,
    pass_hash,
    short_code,
    qr_data,
    'active',
    calculated_expires_at,
    template_entry_limit
  ) RETURNING id INTO new_pass_id;
  
  -- Add the actual UUID, authority, and expiration info to the QR data
  SELECT qr_data || jsonb_build_object(
    'uuid', new_pass_id,
    'authorityId', template_authority_id,
    'expiresAt', calculated_expires_at::text,
    'entriesRemaining', template_entry_limit
  ) INTO updated_qr_data;
  
  -- Update the pass with the enhanced QR data
  UPDATE purchased_passes 
  SET qr_data = updated_qr_data
  WHERE id = new_pass_id;
  
  -- Return the UUID and authority ID
  RETURN QUERY SELECT new_pass_id, template_authority_id;
END;
$$ LANGUAGE plpgsql;

-- Also create a simpler version that doesn't require all the hash/QR parameters
-- This can be used for basic pass creation
CREATE OR REPLACE FUNCTION issue_pass_from_template_simple(
  target_profile_id uuid,
  target_vehicle_id uuid,
  pass_template_id uuid
)
RETURNS TABLE(pass_uuid uuid, authority_id uuid) AS $$
DECLARE
  new_pass_id uuid;
  template_authority_id uuid;
  template_expiration_days int;
  template_entry_limit int;
  calculated_expires_at timestamptz;
  generated_short_code text;
  basic_qr_data jsonb;
BEGIN
  -- Get the authority, expiration days, and entry limit from the pass template
  SELECT pt.authority_id, pt.expiration_days, pt.entry_limit
  INTO template_authority_id, template_expiration_days, template_entry_limit
  FROM pass_templates pt
  WHERE pt.id = pass_template_id;
  
  IF template_authority_id IS NULL THEN
    RAISE EXCEPTION 'Pass template not found or has no authority';
  END IF;
  
  -- Calculate the expiration date
  calculated_expires_at := NOW() + INTERVAL '1 day' * template_expiration_days;
  
  -- Generate a simple short code (you can customize this logic)
  generated_short_code := UPPER(SUBSTRING(MD5(RANDOM()::text), 1, 4)) || '-' || UPPER(SUBSTRING(MD5(RANDOM()::text), 1, 4));
  
  -- Insert the pass with properly calculated fields
  INSERT INTO purchased_passes (
    profile_id,
    vehicle_id,
    pass_template_id,
    authority_id,
    short_code,
    status,
    expires_at,
    entries_remaining
  ) VALUES (
    target_profile_id,
    target_vehicle_id,
    pass_template_id,
    template_authority_id,
    generated_short_code,
    'active',
    calculated_expires_at,
    template_entry_limit
  ) RETURNING id INTO new_pass_id;
  
  -- Create basic QR data with essential information
  SELECT jsonb_build_object(
    'uuid', new_pass_id,
    'passTemplate', pass_template_id,
    'authorityId', template_authority_id,
    'vehicle', target_vehicle_id,
    'issuedAt', NOW()::text,
    'expiresAt', calculated_expires_at::text,
    'entriesRemaining', template_entry_limit,
    'shortCode', generated_short_code
  ) INTO basic_qr_data;
  
  -- Update the pass with the QR data
  UPDATE purchased_passes 
  SET qr_data = basic_qr_data
  WHERE id = new_pass_id;
  
  -- Return the UUID and authority ID
  RETURN QUERY SELECT new_pass_id, template_authority_id;
END;
$$ LANGUAGE plpgsql;
