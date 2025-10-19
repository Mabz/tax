-- Migration: Add out-of-schedule scanning support
-- This migration adds the ability for borders to allow officials to scan outside their scheduled times

-- ========== ADD COLUMN TO BORDERS TABLE ==========
-- Add column to control whether border allows out-of-schedule scans
ALTER TABLE borders 
ADD COLUMN allow_out_of_schedule_scans BOOLEAN DEFAULT false;

-- Add comment for documentation
COMMENT ON COLUMN borders.allow_out_of_schedule_scans IS 'Whether this border allows officials to scan passes outside their scheduled time slots';

-- ========== CREATE INDEX FOR PERFORMANCE ==========
-- Index for quick lookup of border settings during scan validation
CREATE INDEX idx_borders_out_of_schedule_setting 
ON borders(id, allow_out_of_schedule_scans) 
WHERE allow_out_of_schedule_scans = true;

-- ========== UPDATE RLS POLICIES ==========
-- Ensure existing RLS policies cover the new column
-- (Assuming borders table already has proper RLS policies)

-- ========== SAMPLE DATA FOR TESTING ==========
-- Enable out-of-schedule scans for test borders (optional)
-- UPDATE borders SET allow_out_of_schedule_scans = true WHERE name IN ('Ngwenya Border', 'Lavumiso');

-- ========== VERIFICATION QUERIES ==========
-- Verify the column was added successfully
-- SELECT id, name, allow_out_of_schedule_scans FROM borders LIMIT 5;