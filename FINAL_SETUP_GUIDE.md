# Final Setup Guide - Border Control Functions

Since you've cleared the database, here's the clean setup:

## Single File to Run

**File**: `create_correct_border_functions.sql`

This creates everything you need with the correct status flow.

## How to Apply

### Supabase Dashboard
1. Open **SQL Editor**
2. Copy contents of `create_correct_border_functions.sql`
3. Paste and click **Run**
4. Done! ✅

### Supabase CLI
```bash
supabase db execute -f create_correct_border_functions.sql
```

## What It Creates

### Two Function Versions

**Version 1: With Metadata (JSONB)**
```sql
process_pass_movement(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_metadata JSONB
)
```

**Version 2: With Notes (TEXT)**
```sql
process_pass_movement(
    p_pass_id UUID,
    p_border_id UUID,
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_notes TEXT
)
```

Both work - version 2 is a convenience wrapper that calls version 1.

## Status Flow

```
unused → checked_in → checked_out → checked_in → checked_out → ...
  ↓          ↓            ↓            ↓
 -1 entry   no change   no change   -1 entry
```

### Rules
- **Check-In**: Deducts 1 entry, sets status to `checked_in`
- **Check-Out**: No deduction, sets status to `checked_out`
- **Re-Entry**: Deducts 1 entry, sets status to `checked_in`

## App Integration

Your Flutter app already expects these statuses:

```dart
// lib/models/purchased_pass.dart
String get vehicleStatusDisplay {
  switch (currentStatus?.toLowerCase()) {
    case 'unused':
      return 'Not Yet Arrived';    // ✅
    case 'checked_in':
      return 'In Country';          // ✅
    case 'checked_out':
      return 'Departed';            // ✅
    default:
      return 'Status Unknown';
  }
}
```

## Verification

After running the script, verify it worked:

```sql
-- Check functions exist
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'process_pass_movement'
AND n.nspname = 'public';
```

Expected output: 2 functions (one with JSONB, one with TEXT)

## Test It

Create a test pass and process it:

```sql
-- Test check-in
SELECT process_pass_movement(
    'your-pass-id'::UUID,
    'your-border-id'::UUID,
    -26.3054,  -- latitude
    31.1367,   -- longitude
    'Test check-in'::TEXT
);
```

Should return:
```json
{
  "success": true,
  "movement_type": "check_in",
  "previous_status": "unused",
  "new_status": "checked_in",
  "entries_deducted": 1,
  "entries_remaining": 4
}
```

## That's It!

No migration needed, no old data to clean up. Just run the one file and you're done.

## Summary

✅ **Run**: `create_correct_border_functions.sql`  
✅ **Status Flow**: unused → checked_in → checked_out  
✅ **Entry Deduction**: Only on check-in  
✅ **App Compatible**: Matches Flutter app expectations  
✅ **Clean Start**: No legacy issues
