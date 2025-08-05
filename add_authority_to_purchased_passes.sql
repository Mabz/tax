-- =====================================================
-- ADD AUTHORITY TO PURCHASED PASSES
-- =====================================================
-- This migration adds authority tracking to purchased passes
-- to support the authority-centric model

-- Step 1: Add authority_id column to purchased_passes table
ALTER TABLE public.purchased_passes 
ADD COLUMN authority_id uuid;

-- Step 2: Add foreign key constraint to authorities table
ALTER TABLE public.purchased_passes 
ADD CONSTRAINT purchased_passes_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

-- Step 3: Create index for performance
CREATE INDEX idx_purchased_passes_authority_id ON public.purchased_passes(authority_id);

-- Step 4: Populate authority_id for existing passes
-- This gets the authority from the pass template
UPDATE public.purchased_passes 
SET authority_id = (
  SELECT pt.authority_id 
  FROM public.pass_templates pt 
  WHERE pt.id = purchased_passes.pass_template_id
);

-- Step 5: Update the issue_pass_from_template function to include authority
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
  updated_qr_data jsonb;
BEGIN
  -- Get the authority from the pass template
  SELECT pt.authority_id INTO template_authority_id
  FROM pass_templates pt
  WHERE pt.id = pass_template_id;
  
  IF template_authority_id IS NULL THEN
    RAISE EXCEPTION 'Pass template not found or has no authority';
  END IF;
  
  -- Insert the pass and get the generated UUID
  INSERT INTO purchased_passes (
    profile_id,
    vehicle_id,
    pass_template_id,
    authority_id,
    pass_hash,
    short_code,
    qr_data,
    status
  ) VALUES (
    target_profile_id,
    target_vehicle_id,
    pass_template_id,
    template_authority_id,
    pass_hash,
    short_code,
    qr_data,
    'active'
  ) RETURNING id INTO new_pass_id;
  
  -- Add the actual UUID and authority to the QR data
  SELECT qr_data || jsonb_build_object(
    'uuid', new_pass_id,
    'authorityId', template_authority_id
  ) INTO updated_qr_data;
  
  -- Update the pass with the enhanced QR data
  UPDATE purchased_passes 
  SET qr_data = updated_qr_data
  WHERE id = new_pass_id;
  
  -- Return the UUID and authority ID
  RETURN QUERY SELECT new_pass_id, template_authority_id;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Update the get_passes_for_profile function to include authority info
CREATE OR REPLACE FUNCTION get_passes_for_profile(target_profile_id uuid)
RETURNS TABLE (
  pass_id text,
  vehicle_desc text,
  pass_description text,
  border_name text,
  entry_limit int,
  entries_remaining int,
  issued_at timestamptz,
  expires_at timestamptz,
  status text,
  currency text,
  amount numeric,
  qr_data jsonb,
  short_code text,
  authority_id uuid,
  authority_name text,
  country_name text
) 
LANGUAGE sql
AS $$
  SELECT
    pp.id::text as pass_id,
    COALESCE(v.description || ' (' || v.number_plate || ')', 'Unknown Vehicle') as vehicle_desc,
    pt.description as pass_description,
    b.name as border_name,
    pt.entry_limit,
    pp.entries_remaining,
    pp.issued_at,
    pp.expires_at,
    pp.status,
    pt.currency_code as currency,
    pt.tax_amount as amount,
    pp.qr_data,
    pp.short_code,
    a.id as authority_id,
    a.name as authority_name,
    c.name as country_name
  FROM purchased_passes pp
  JOIN pass_templates pt ON pt.id = pp.pass_template_id
  LEFT JOIN vehicles v ON v.id = pp.vehicle_id
  LEFT JOIN borders b ON b.id = pt.border_id
  LEFT JOIN authorities a ON a.id = pp.authority_id
  LEFT JOIN countries c ON c.id = a.country_id
  WHERE pp.profile_id = target_profile_id
  ORDER BY pp.issued_at DESC;
$$;

-- Step 7: Update get_passes_for_user function (alternative name)
CREATE OR REPLACE FUNCTION get_passes_for_user(target_profile_id uuid)
RETURNS TABLE (
  pass_id text,
  vehicle_desc text,
  pass_description text,
  border_name text,
  entry_limit int,
  entries_remaining int,
  issued_at timestamptz,
  expires_at timestamptz,
  status text,
  currency text,
  amount numeric,
  qr_data jsonb,
  short_code text,
  authority_id uuid,
  authority_name text,
  country_name text
) 
LANGUAGE sql
AS $$
  SELECT * FROM get_passes_for_profile(target_profile_id);
$$;

-- Step 8: Create function to get passes by authority (for authority admins)
CREATE OR REPLACE FUNCTION get_passes_for_authority(target_authority_id uuid)
RETURNS TABLE (
  pass_id text,
  vehicle_desc text,
  pass_description text,
  border_name text,
  entry_limit int,
  entries_remaining int,
  issued_at timestamptz,
  expires_at timestamptz,
  status text,
  currency text,
  amount numeric,
  qr_data jsonb,
  short_code text,
  profile_id uuid,
  profile_name text,
  profile_email text
) 
LANGUAGE sql
AS $$
  SELECT
    pp.id::text as pass_id,
    COALESCE(v.description || ' (' || v.number_plate || ')', 'Unknown Vehicle') as vehicle_desc,
    pt.description as pass_description,
    b.name as border_name,
    pt.entry_limit,
    pp.entries_remaining,
    pp.issued_at,
    pp.expires_at,
    pp.status,
    pt.currency_code as currency,
    pt.tax_amount as amount,
    pp.qr_data,
    pp.short_code,
    p.id as profile_id,
    p.full_name as profile_name,
    p.email as profile_email
  FROM purchased_passes pp
  JOIN pass_templates pt ON pt.id = pp.pass_template_id
  LEFT JOIN vehicles v ON v.id = pp.vehicle_id
  LEFT JOIN borders b ON b.id = pt.border_id
  JOIN profiles p ON p.id = pp.profile_id
  WHERE pp.authority_id = target_authority_id
  ORDER BY pp.issued_at DESC;
$$;

-- Step 9: Add RLS policies for authority-based access
-- Allow users to see their own passes
CREATE POLICY "Users can view their own passes" ON purchased_passes
  FOR SELECT USING (profile_id = auth.uid());

-- Allow authority admins to see passes issued by their authority
CREATE POLICY "Authority admins can view their authority passes" ON purchased_passes
  FOR SELECT USING (
    authority_id IN (
      SELECT pr.authority_id 
      FROM profile_roles pr 
      JOIN roles r ON r.id = pr.role_id 
      WHERE pr.profile_id = auth.uid() 
      AND r.name IN ('country_admin', 'border_official')
      AND pr.is_active = true
    )
  );

-- Allow superusers to see all passes
CREATE POLICY "Superusers can view all passes" ON purchased_passes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profile_roles pr 
      JOIN roles r ON r.id = pr.role_id 
      WHERE pr.profile_id = auth.uid() 
      AND r.name = 'superuser'
      AND pr.is_active = true
    )
  );

-- Enable RLS on purchased_passes table
ALTER TABLE purchased_passes ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT SELECT ON purchased_passes TO anon, authenticated;
GRANT INSERT ON purchased_passes TO authenticated;
GRANT UPDATE ON purchased_passes TO authenticated;
