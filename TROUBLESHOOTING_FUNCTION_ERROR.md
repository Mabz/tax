# Troubleshooting: "function name is not unique" Error

## The Error
```
ERROR: 42725: function name "process_pass_movement" is not unique
HINT: Specify the argument list to select the function unambiguously.
```

## What This Means
Your database has multiple versions of the `process_pass_movement` function with different parameter signatures. PostgreSQL doesn't know which one to drop/replace.

## Solution: Use the Simple Version

Instead of `fix_in_transit_status.sql`, use:
```
fix_in_transit_status_simple.sql
```

This version explicitly drops all possible function signatures before creating the new one.

## How to Apply

### In Supabase Dashboard
1. Open **SQL Editor**
2. Copy contents of `fix_in_transit_status_simple.sql`
3. Paste and click **Run**

### Using Supabase CLI
```bash
supabase db execute -f fix_in_transit_status_simple.sql
```

## What the Simple Version Does

### Step 1: Update Data
```sql
UPDATE purchased_passes
SET current_status = 'checked_in'
WHERE current_status = 'in_transit';
```

### Step 2: Drop ALL Function Versions
```sql
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, JSONB) CASCADE;
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, DECIMAL, DECIMAL, TEXT) CASCADE;
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, NUMERIC, NUMERIC, JSONB) CASCADE;
DROP FUNCTION IF EXISTS process_pass_movement(UUID, UUID, NUMERIC, NUMERIC, TEXT) CASCADE;
-- ... and more variations
```

### Step 3: Create New Corrected Function
Creates the function with proper status flow:
- `unused` → `checked_in` (deduct 1 entry)
- `checked_in` → `checked_out` (no deduction)
- `checked_out` → `checked_in` (deduct 1 entry)

## Verification

After running, check that it worked:

```sql
-- Check status update
SELECT current_status, COUNT(*) 
FROM purchased_passes 
GROUP BY current_status;
```

Expected: No `in_transit` status should appear.

```sql
-- Check function exists
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'process_pass_movement'
AND n.nspname = 'public';
```

Expected: Should show 2 versions (one with JSONB, one with TEXT parameter).

## Still Having Issues?

### Option 1: Manual Cleanup
If the simple version still fails, manually drop all functions first:

```sql
-- Find all versions
SELECT 
    p.oid::regprocedure as full_signature
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'process_pass_movement'
AND n.nspname = 'public';
```

Then drop each one individually:
```sql
DROP FUNCTION [paste full signature here] CASCADE;
```

### Option 2: Nuclear Option
Drop by name (drops ALL versions):

```sql
DROP FUNCTION process_pass_movement CASCADE;
```

⚠️ **Warning**: This will drop ALL versions and any dependent objects. Only use if you're sure.

Then run `fix_in_transit_status_simple.sql` to recreate the correct version.

## Why This Happened

You likely ran multiple SQL scripts that created different versions of the function:
- `create_border_movement_functions.sql`
- `create_process_pass_movement_function.sql`
- `fix_duplicate_function_error.sql`

Each created slightly different versions, causing the conflict.

## Prevention

Going forward:
1. Always use `CREATE OR REPLACE FUNCTION` with full signature
2. Drop old versions before creating new ones
3. Use the `CASCADE` option when dropping functions
4. Keep only one authoritative SQL file for each function

## Summary

✅ **Use**: `fix_in_transit_status_simple.sql`  
❌ **Avoid**: Running multiple function creation scripts  
🎯 **Goal**: Single corrected function with proper status flow
