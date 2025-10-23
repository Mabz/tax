# Entries Deducted Bug Fix

## Problem Identified
All audit trail entries were showing "Entries Deducted: 1" in red, even when the database had `entries_deducted: 0`. This was causing incorrect display of entry impact.

## Root Cause Analysis

### Issue 1: Hardcoded Value
In `_getMovementsByProfileId()` method, the PassMovement object was created with:
```dart
entriesDeducted: 1, // Default for scans  ❌ WRONG
```

### Issue 2: Missing Database Column
The database query was not selecting the `entries_deducted` column:
```sql
SELECT id, pass_id, movement_type, latitude, longitude, created_at, scan_purpose, notes, ...
-- Missing: entries_deducted
```

## Fixes Applied

### Fix 1: Use Actual Database Value
```dart
// Before (hardcoded)
entriesDeducted: 1, // Default for scans

// After (from database)
entriesDeducted: record['entries_deducted'] as int? ?? 0,
```

### Fix 2: Add Missing Column to Query
```sql
SELECT 
  id,
  pass_id,
  movement_type,
  entries_deducted,  -- ✅ ADDED
  latitude,
  longitude,
  created_at,
  scan_purpose,
  notes,
  ...
```

## Expected Results After Fix

### For Your Example Data
```json
{
  "entries_deducted": 0,
  "notes": "Checking stuff out",
  "scan_purpose": "roadblock"
}
```

**Should now display:**
```
🚔 Roadblock
Bobby • Local Authority
⏰ 26m ago 📝 Checking stuff out
                    [Entries Deducted: 0] 🟢 (Green)
```

### For Actual Entry Deductions
```json
{
  "entries_deducted": 1,
  "notes": "Vehicle inspection completed",
  "scan_purpose": "security_check"
}
```

**Should display:**
```
🚔 Security Check
Bobby • Local Authority
⏰ 1h ago 📝 Vehicle inspection completed
                    [Entries Deducted: 1] 🔴 (Red)
```

## Verification Steps

1. **Check Database Values**: Verify `entries_deducted` column contains correct values
2. **Test Zero Deductions**: Confirm activities with 0 entries show green badge
3. **Test Actual Deductions**: Confirm activities with >0 entries show red badge
4. **Color Coding**: Verify green for 0, red for >0

## Impact

- **Accurate Display**: Now shows actual database values instead of hardcoded 1
- **Correct Color Coding**: Green for no impact, red for actual impact
- **Better UX**: Officials can trust the visual indicators
- **Data Integrity**: Display matches actual database state

## Technical Notes

- The fix ensures data consistency between database and UI
- Maintains backward compatibility with existing data
- Handles null values gracefully with `?? 0` fallback
- No changes needed to color coding logic (already correct)