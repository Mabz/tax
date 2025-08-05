-- Fix profile_roles table structure for authority-centric model
-- This script migrates from country_id to authority_id if needed

-- Step 1: Check current table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profile_roles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Step 2: If the table still has country_id, we need to migrate it
-- First, let's see what we're working with
SELECT COUNT(*) as total_roles FROM profile_roles;

-- Step 3: Migration script (only run if country_id column exists)
-- This assumes you have an authorities table with country_id mapping

-- BACKUP EXISTING DATA FIRST!
-- CREATE TABLE profile_roles_backup AS SELECT * FROM profile_roles;

-- If country_id column exists and authority_id doesn't, run this migration:
/*
-- Add authority_id column if it doesn't exist
ALTER TABLE profile_roles ADD COLUMN IF NOT EXISTS authority_id uuid;

-- Update authority_id based on country_id mapping
UPDATE profile_roles pr
SET authority_id = a.id
FROM authorities a
WHERE a.country_id = pr.country_id
AND a.is_active = true;

-- Add foreign key constraint
ALTER TABLE profile_roles 
ADD CONSTRAINT fk_profile_roles_authority 
FOREIGN KEY (authority_id) REFERENCES authorities(id);

-- Drop the old country_id column (CAREFUL!)
-- ALTER TABLE profile_roles DROP COLUMN IF EXISTS country_id;

-- Update unique constraints if they exist
-- DROP CONSTRAINT IF EXISTS unique_profile_role_country;
-- ALTER TABLE profile_roles 
-- ADD CONSTRAINT unique_profile_role_authority 
-- UNIQUE (profile_id, role_id, authority_id);
*/

-- Step 4: Verify the correct structure
-- The profile_roles table should have these columns:
-- - id (uuid, primary key)
-- - profile_id (uuid, foreign key to profiles)
-- - role_id (uuid, foreign key to roles)  
-- - authority_id (uuid, foreign key to authorities) <- NOT country_id
-- - assigned_by_profile_id (uuid, foreign key to profiles)
-- - assigned_at (timestamptz)
-- - is_active (boolean)

-- Step 5: Create the table with correct structure if it doesn't exist
CREATE TABLE IF NOT EXISTS profile_roles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  authority_id uuid NOT NULL REFERENCES authorities(id) ON DELETE CASCADE,
  assigned_by_profile_id uuid REFERENCES profiles(id),
  assigned_at timestamptz DEFAULT NOW(),
  is_active boolean DEFAULT true,
  UNIQUE(profile_id, role_id, authority_id)
);

-- Step 6: Enable RLS if not already enabled
ALTER TABLE profile_roles ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS policies for profile_roles
DROP POLICY IF EXISTS "Users can view their own roles" ON profile_roles;
CREATE POLICY "Users can view their own roles" ON profile_roles
  FOR SELECT USING (profile_id = auth.uid());

DROP POLICY IF EXISTS "Admins can manage roles" ON profile_roles;
CREATE POLICY "Admins can manage roles" ON profile_roles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      WHERE pr.profile_id = auth.uid()
      AND r.name IN ('superuser', 'country_admin')
      AND pr.is_active = true
    )
  );

-- Step 8: Grant permissions
GRANT SELECT ON profile_roles TO authenticated;
GRANT INSERT, UPDATE ON profile_roles TO authenticated;
