# Function Overloading Fix - Movement History

## ❌ **Error Encountered**
```
PostgrestException: Could not choose the best candidate function between: 
public.get_pass_movement_history(p_pass_id => text), 
public.get_pass_movement_history(p_pass_id => uuid)
Multiple Choices - Try renaming the parameters or the function
```

## 🔍 **Root Cause**
- Multiple versions of `get_pass_movement_history` function exist in database
- PostgreSQL cannot determine which function to use (TEXT vs UUID parameter)
- Function overloading conflict prevents proper execution

## ✅ **Solution**

### Step 1: Run the Fix Script
Execute this SQL in Supabase SQL Editor:

```sql
-- Run the contents of fix_movement_history_function_conflict.sql
```

This will:
- ✅ Drop all existing versions of the function
- ✅ Create a single, properly defined function
- ✅ Accept TEXT parameter and convert to UUID internally
- ✅ Include profile image and authority name enhancements

### Step 2: Verify the Fix
Check that only one function exists:

```sql
SELECT 
    proname,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc 
WHERE proname = 'get_pass_movement_history';
```

Should return only one row with TEXT parameter.

## 🔧 **What the Fix Does**

### Function Signature
```sql
get_pass_movement_history(p_pass_id TEXT)
```

### Enhanced Features
- ✅ **Profile Images**: Includes `official_profile_image_url`
- ✅ **Authority Names**: Shows actual authority names instead of "Local Authority"
- ✅ **Proper Joins**: Links with profiles, borders, and authorities tables
- ✅ **Type Safety**: Converts TEXT to UUID internally

### Return Structure
```sql
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,                    -- Real authority names
    official_name TEXT,
    official_profile_image_url TEXT,     -- New: Profile images
    movement_type TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    processed_at TIMESTAMP WITH TIME ZONE,
    entries_deducted INTEGER,
    previous_status TEXT,
    new_status TEXT
)
```

## 🧪 **Testing the Fix**

### Test Query
```sql
SELECT * FROM get_pass_movement_history('your-pass-id-here');
```

### Expected Results
- ✅ No function overloading error
- ✅ Movement history returns successfully
- ✅ Profile image URLs included (may be null if not set)
- ✅ Real authority names instead of "Local Authority"

## 🚨 **If Issues Persist**

### Check for Remaining Functions
```sql
-- List all functions with this name
SELECT proname, proargtypes, prosrc 
FROM pg_proc 
WHERE proname LIKE '%movement_history%';
```

### Manual Cleanup (if needed)
```sql
-- Drop any remaining conflicting functions
DROP FUNCTION IF EXISTS get_pass_movement_history CASCADE;
```

Then re-run the fix script.

## ✅ **Expected App Behavior**

After applying the fix:

1. **Movement History Loads**: No more function overloading errors
2. **Profile Images Show**: Official profile pictures appear in movement history
3. **Authority Names**: Real authority names instead of generic "Local Authority"
4. **Drawer Profile**: User profile image appears in navigation drawer

## 📋 **Status Check**

Run this to verify everything is working:

```sql
-- Check function exists and works
SELECT COUNT(*) as function_exists 
FROM pg_proc 
WHERE proname = 'get_pass_movement_history';

-- Test with a sample pass ID (replace with real ID)
-- SELECT * FROM get_pass_movement_history('sample-uuid-here') LIMIT 1;
```

The function conflict should now be completely resolved! 🎯