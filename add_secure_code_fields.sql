-- Add secure code fields to purchased_passes table
-- Run this in your Supabase SQL editor

ALTER TABLE purchased_passes 
ADD COLUMN secure_code VARCHAR(6),
ADD COLUMN secure_code_expires_at TIMESTAMP WITH TIME ZONE;

-- Create index for efficient queries
CREATE INDEX idx_purchased_passes_secure_code_expires 
ON purchased_passes(secure_code_expires_at) 
WHERE secure_code IS NOT NULL;