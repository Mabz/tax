-- Updated function to issue pass and return the UUID for QR code generation
-- This allows us to include the actual database UUID in the QR code

CREATE OR REPLACE FUNCTION issue_pass_from_template_with_uuid(
  target_profile_id uuid,
  target_vehicle_id uuid,
  pass_template_id uuid,
  short_code text
)
RETURNS TABLE(pass_uuid uuid) AS $$
DECLARE
  new_pass_id uuid;
  qr_data_with_uuid jsonb;
BEGIN
  -- Insert the pass and get the generated UUID
  INSERT INTO purchased_passes (
    profile_id,
    vehicle_id,
    pass_template_id,
    short_code,
    status
  ) VALUES (
    target_profile_id,
    target_vehicle_id,
    pass_template_id,
    short_code,
    'active'
  ) RETURNING id INTO new_pass_id;
  
  -- Create QR data with the actual UUID
  SELECT jsonb_build_object(
    'uuid', new_pass_id,
    'passTemplate', pass_template_id,
    'vehicle', target_vehicle_id,
    'issuedAt', now()::text,
    'shortCode', short_code
  ) INTO qr_data_with_uuid;
  
  -- Update the pass with the QR data containing the UUID
  UPDATE purchased_passes 
  SET qr_data = qr_data_with_uuid
  WHERE id = new_pass_id;
  
  -- Return the UUID
  RETURN QUERY SELECT new_pass_id;
END;
$$ LANGUAGE plpgsql;

-- Alternative: Update existing function to return UUID
CREATE OR REPLACE FUNCTION issue_pass_from_template(
  target_profile_id uuid,
  target_vehicle_id uuid,
  pass_template_id uuid,
  pass_hash text,
  short_code text,
  qr_data jsonb
)
RETURNS TABLE(pass_uuid uuid) AS $$
DECLARE
  new_pass_id uuid;
  updated_qr_data jsonb;
BEGIN
  -- Insert the pass and get the generated UUID
  INSERT INTO purchased_passes (
    profile_id,
    vehicle_id,
    pass_template_id,
    pass_hash,
    short_code,
    qr_data,
    status
  ) VALUES (
    target_profile_id,
    target_vehicle_id,
    pass_template_id,
    pass_hash,
    short_code,
    qr_data,
    'active'
  ) RETURNING id INTO new_pass_id;
  
  -- Add the actual UUID to the QR data
  SELECT qr_data || jsonb_build_object('uuid', new_pass_id) INTO updated_qr_data;
  
  -- Update the pass with the enhanced QR data
  UPDATE purchased_passes 
  SET qr_data = updated_qr_data
  WHERE id = new_pass_id;
  
  -- Return the UUID
  RETURN QUERY SELECT new_pass_id;
END;
$$ LANGUAGE plpgsql;
