-- Fix missing assigned_by column in border_official_borders table
-- This script adds the missing column that's causing the assignment error

-- Add assigned_by column if it doesn't exist
ALTER TABLE border_official_borders 
ADD COLUMN IF NOT EXISTS assigned_by UUID REFERENCES profiles(id);

-- Add revoked_by column if it doesn't exist
ALTER TABLE border_official_borders 
ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES profiles(id);

-- Add revoked_at column if it doesn't exist
ALTER TABLE border_official_borders 
ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMP WITH TIME ZONE;

-- Add assigned_at column if it doesn't exist
ALTER TABLE border_official_borders 
ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing records to have assigned_at if they don't
UPDATE border_official_borders 
SET assigned_at = created_at 
WHERE assigned_at IS NULL AND created_at IS NOT NULL;

-- Update existing records to have assigned_at as NOW() if both are null
UPDATE border_official_borders 
SET assigned_at = NOW() 
WHERE assigned_at IS NULL;