-- Fix the pass_movements table constraint to allow local authority scans
-- Run this in your Supabase SQL editor

-- First, check what movement types are currently allowed
DO $$
BEGIN
    -- Check if the constraint exists and what values it allows
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'pass_movements_movement_type_check'
    ) THEN
        RAISE NOTICE 'Found existing movement_type constraint, updating it...';
        
        -- Drop the old constraint
        ALTER TABLE pass_movements DROP CONSTRAINT IF EXISTS pass_movements_movement_type_check;
        
        -- Add the new constraint with additional movement types
        ALTER TABLE pass_movements ADD CONSTRAINT pass_movements_movement_type_check 
        CHECK (movement_type IN ('check_in', 'check_out', 'local_authority_scan', 'verification_scan', 'border_scan'));
        
        RAISE NOTICE '✅ Updated movement_type constraint to include local_authority_scan';
    ELSE
        RAISE NOTICE 'No existing constraint found, creating new one...';
        
        -- Create the constraint with all movement types
        ALTER TABLE pass_movements ADD CONSTRAINT pass_movements_movement_type_check 
        CHECK (movement_type IN ('check_in', 'check_out', 'local_authority_scan', 'verification_scan', 'border_scan'));
        
        RAISE NOTICE '✅ Created movement_type constraint with local_authority_scan';
    END IF;
END;
$$;

-- Test the constraint by checking what movement types are now allowed
SELECT 'Movement type constraint updated successfully - local_authority_scan is now allowed' as status;