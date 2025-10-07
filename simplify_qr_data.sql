-- Simplify QR Data for Border Control
-- This script removes complex QR data and replaces it with just the pass ID
-- Making QR codes simpler and easier to scan

-- Step 1: Drop any triggers that might be auto-generating complex QR data
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN 
        SELECT tgname, tgrelid::regclass AS table_name
        FROM pg_trigger
        WHERE tgrelid = 'purchased_passes'::regclass
        AND tgname LIKE '%qr%'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', trigger_record.tgname, trigger_record.table_name);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.tgname;
    END LOOP;
END $$;

-- Step 2: Update all existing passes to have simple QR data (just the ID)
UPDATE purchased_passes
SET qr_data = jsonb_build_object('id', id::text)
WHERE qr_data IS NOT NULL 
  AND qr_data != jsonb_build_object('id', id::text);

-- Step 3: Verify the update
DO $$
DECLARE
    updated_count INTEGER;
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count
    FROM purchased_passes
    WHERE qr_data = jsonb_build_object('id', id::text);
    
    SELECT COUNT(*) INTO total_count
    FROM purchased_passes
    WHERE qr_data IS NOT NULL;
    
    RAISE NOTICE 'Updated % out of % passes to simple QR format', updated_count, total_count;
END $$;

-- Step 4: Add a comment to the column to document the expected format
COMMENT ON COLUMN purchased_passes.qr_data IS 'Simple QR data containing only the pass ID in format: {"id": "uuid"}. This is scanned by both Local Authority and Border Control officials.';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ QR data simplification complete!';
    RAISE NOTICE '   - All passes now have simple QR format: {"id": "pass-uuid"}';
    RAISE NOTICE '   - Any auto-generation triggers have been removed';
    RAISE NOTICE '   - Border Control and Local Authority use the same scanner';
END $$;
