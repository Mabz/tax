# Fix in_transit Status Issue

## Problem
The database functions were using an "in_transit" status that doesn't exist in the app's logic, causing confusion in the pass dashboard. The app expects only three statuses:
- `unused` - Vehicle has not yet crossed the border
- `checked_in` - Vehicle has entered the country
- `checked_out` - Vehicle has exited the country

## Root Cause
The SQL functions (`process_pass_movement`) were setting `current_status = 'in_transit'` when a vehicle checked in, but the Flutter app's `PurchasedPass` model only recognizes `checked_in`, `checked_out`, and `unused`.

## Solution
Created `fix_in_transit_status.sql` which:

### 1. Updates Existing Data
```sql
UPDATE purchased_passes
SET current_status = 'checked_in'
WHERE current_status = 'in_transit';
```

### 2. Fixes the Database Function
Corrected the status flow in `process_pass_movement`:
- **unused → checked_in** (first entry, deducts 1 entry)
- **checked_in → checked_out** (exit, no deduction)
- **checked_out → checked_in** (re-entry, deducts 1 entry)

### 3. Removes the Invalid Status
The function now only uses the three valid statuses that the app recognizes.

## Status Flow

### Before (Broken)
```
unused → in_transit → active
       ❌ in_transit not recognized by app
```

### After (Fixed)
```
unused → checked_in → checked_out → checked_in → ...
  ✅ All statuses recognized by app
```

## How to Apply

### Option 1: Supabase Dashboard
1. Open your Supabase dashboard
2. Go to **SQL Editor**
3. Copy and paste the contents of `fix_in_transit_status.sql`
4. Click **Run**

### Option 2: Supabase CLI
```bash
supabase db execute -f fix_in_transit_status.sql
```

## What Gets Fixed

### Database
- All passes with `in_transit` status → `checked_in`
- Function updated to use correct status flow
- Future passes will use correct statuses

### App Display
The `PurchasedPass` model already handles these statuses correctly:

```dart
String get vehicleStatusDisplay {
  switch (currentStatus?.toLowerCase()) {
    case 'unused':
      return 'Not Yet Arrived';
    case 'checked_in':
      return 'In Country';      // ✅ Now works correctly
    case 'checked_out':
      return 'Departed';
    default:
      return 'Status Unknown';  // ❌ Was showing this for in_transit
  }
}
```

## Verification

After running the script, verify:

1. **Check Database**:
   ```sql
   SELECT current_status, COUNT(*) 
   FROM purchased_passes 
   GROUP BY current_status;
   ```
   Should show: `unused`, `checked_in`, `checked_out` (no `in_transit`)

2. **Check App**:
   - Open pass dashboard
   - Vehicle status should show "In Country" or "Departed"
   - No more "Status Unknown" for active passes

3. **Test Border Control**:
   - Scan a pass with Border Official role
   - Check-in should set status to `checked_in`
   - Check-out should set status to `checked_out`

## Files Modified

### SQL Files (Need to run)
- ✅ `fix_in_transit_status.sql` - Main fix (NEW)

### SQL Files (Old, can be ignored)
- ❌ `create_border_movement_functions.sql` - Has old in_transit logic
- ❌ `create_process_pass_movement_function.sql` - Has old in_transit logic
- ❌ `fix_duplicate_function_error.sql` - Has old in_transit logic

### Dart Files (Already Correct)
- ✅ `lib/models/purchased_pass.dart` - Already uses correct statuses
- ✅ `lib/services/enhanced_border_service.dart` - Already uses correct statuses

## Benefits

1. **Consistent Status Display**: Pass dashboard shows correct vehicle status
2. **Clear Status Flow**: Easy to understand: unused → checked_in → checked_out
3. **No Confusion**: All statuses match between database and app
4. **Better UX**: Users see "In Country" instead of "Status Unknown"

## Notes

- The app code was already correct - no Dart changes needed
- Only the database functions needed fixing
- This is a one-time fix - future passes will work correctly
- The check-in/check-out logic remains unchanged and working
