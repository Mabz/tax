# Quick Guide: Apply Database Fixes

You have two SQL fixes to apply to your Supabase database:

## 1. Simplify QR Code Data ✅
**File**: `simplify_qr_data.sql`

**What it fixes**: 
- Removes complex JSON from QR codes
- Makes QR codes contain only the pass ID
- Improves scanning reliability

**Run this first**

---

## 2. Fix in_transit Status ✅
**File**: `fix_in_transit_status.sql` (or `fix_in_transit_status_simple.sql` if you get errors)

**What it fixes**:
- Removes invalid "in_transit" status
- Updates passes to use "checked_in" instead
- Fixes pass dashboard display issues

**Run this second**

**Note**: If you get a "function name is not unique" error, use `fix_in_transit_status_simple.sql` instead

---

## How to Apply (Choose One Method)

### Method 1: Supabase Dashboard (Recommended)

1. Open your Supabase project dashboard
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the contents of `simplify_qr_data.sql`
5. Paste into the editor
6. Click **Run** (or press Ctrl+Enter)
7. Wait for success message
8. Repeat steps 3-7 for `fix_in_transit_status.sql`

### Method 2: Supabase CLI

```bash
# Make sure you're in the project directory
cd /path/to/easytax

# Apply QR code fix
supabase db execute -f simplify_qr_data.sql

# Apply status fix
supabase db execute -f fix_in_transit_status.sql
```

---

## Verification

### After Running simplify_qr_data.sql

Check that QR data is simplified:
```sql
SELECT 
  id, 
  qr_data 
FROM purchased_passes 
LIMIT 5;
```

Expected result: `qr_data` should be `{"id": "uuid"}` (simple format)

### After Running fix_in_transit_status.sql

Check that no in_transit status exists:
```sql
SELECT 
  current_status, 
  COUNT(*) 
FROM purchased_passes 
GROUP BY current_status;
```

Expected result: Should show `unused`, `checked_in`, `checked_out` (no `in_transit`)

---

## What to Expect

### Before Fixes
- ❌ QR codes contain huge JSON blobs
- ❌ Pass dashboard shows "Status Unknown"
- ❌ Vehicle status not displaying correctly

### After Fixes
- ✅ QR codes are simple and scan quickly
- ✅ Pass dashboard shows "In Country" or "Departed"
- ✅ Vehicle status displays correctly
- ✅ Both Local Authority and Border Control use same scanner

---

## Troubleshooting

### If you get "function name is not unique" error
Use `fix_in_transit_status_simple.sql` instead of `fix_in_transit_status.sql`. This version explicitly drops all function signatures.

### If you get "function does not exist" error
This is normal - the script will create the missing functions.

### If you get "permission denied" error
Make sure you're logged in as the database owner or have SUPERUSER privileges.

### If QR codes still show complex data
1. Check if the script ran successfully
2. Try refreshing your app
3. Create a new test pass to verify

### If status still shows "Status Unknown"
1. Verify the script ran successfully
2. Check the database with the verification query above
3. Restart your app to clear any cached data

---

## Need Help?

If you encounter any issues:
1. Check the Supabase logs in the dashboard
2. Look for error messages in the SQL Editor
3. Verify you're connected to the correct database
4. Make sure you have the necessary permissions

---

## Summary

✅ **simplify_qr_data.sql** - Makes QR codes simple and scannable  
✅ **fix_in_transit_status.sql** - Fixes pass status display issues

Both scripts are safe to run and will not delete any data. They only update existing records to use the correct format.
