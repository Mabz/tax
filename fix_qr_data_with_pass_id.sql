-- Fix existing QR data to include the actual pass ID
-- This script updates existing passes to include the pass ID in their QR data

DO $$
DECLARE
    v_pass_record RECORD;
    v_updated_qr_data JSONB;
    v_updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Fixing QR data to include pass IDs';
    RAISE NOTICE '=================================================================';
    
    -- Loop through all active passes that have QR data but missing pass ID
    FOR v_pass_record IN 
        SELECT id, qr_data
        FROM purchased_passes 
        WHERE qr_data IS NOT NULL 
          AND status = 'active'
          AND (qr_data->>'id' IS NULL OR qr_data->>'id' = '')
    LOOP
        -- Add the pass ID to the QR data
        v_updated_qr_data := v_pass_record.qr_data || jsonb_build_object('id', v_pass_record.id::text);
        
        -- Update the pass with the corrected QR data
        UPDATE purchased_passes 
        SET qr_data = v_updated_qr_data
        WHERE id = v_pass_record.id;
        
        v_updated_count := v_updated_count + 1;
        
        RAISE NOTICE 'Updated pass %: Added ID to QR data', v_pass_record.id;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated % passes with missing pass IDs in QR data', v_updated_count;
    
    -- Also check for passes that might need the pass_id field (alternative key)
    v_updated_count := 0;
    
    FOR v_pass_record IN 
        SELECT id, qr_data
        FROM purchased_passes 
        WHERE qr_data IS NOT NULL 
          AND status = 'active'
          AND (qr_data->>'pass_id' IS NULL OR qr_data->>'pass_id' = '')
          AND (qr_data->>'id' IS NOT NULL AND qr_data->>'id' != '')
    LOOP
        -- Add the pass_id field as well for compatibility
        v_updated_qr_data := v_pass_record.qr_data || jsonb_build_object('pass_id', v_pass_record.id::text);
        
        -- Update the pass with the corrected QR data
        UPDATE purchased_passes 
        SET qr_data = v_updated_qr_data
        WHERE id = v_pass_record.id;
        
        v_updated_count := v_updated_count + 1;
        
        RAISE NOTICE 'Updated pass %: Added pass_id to QR data', v_pass_record.id;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated % passes with missing pass_id field in QR data', v_updated_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'QR data fix complete!';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Run debug_qr_verification.sql to test QR scanning';
    RAISE NOTICE '2. Test QR code scanning in the app';
    RAISE NOTICE '3. Verify that both QR codes and backup codes work';
    RAISE NOTICE '=================================================================';
END $$;