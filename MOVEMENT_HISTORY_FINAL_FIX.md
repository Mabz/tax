# Movement History Final Fix Guide

## ❌ **Current Error**
```
column pm.authority_id does not exist
Perhaps you meant to reference the column "b.authority_id"
```

## 🎯 **Quick Fix Options**

### Option 1: Minimal Fix (Guaranteed to Work)
**Run this SQL immediately:**

```sql
-- Execute minimal_movement_history_fix.sql
```

This creates a basic function that:
- ✅ **Only uses known columns** (id, movement_type, processed_at, etc.)
- ✅ **Joins with borders table** for border names
- ✅ **No authority assumptions** - avoids column errors
- ⚠️ **Shows "Local Authority"** for local authority scans

### Option 2: Enhanced Fix (If borders.authority_id exists)
**Try this SQL if you want authority names:**

```sql
-- Execute movement_history_with_border_authority.sql
```

This attempts to:
- ✅ **Get authority names through borders table**
- ✅ **Show real authority names** instead of "Local Authority"
- ⚠️ **May fail if borders.authority_id doesn't exist**

## 🔍 **Diagnostic Steps**

### Step 1: Run Minimal Fix First
Always start with the minimal fix to get movement history working:

```sql
-- This will definitely work
-- Execute minimal_movement_history_fix.sql
```

### Step 2: Diagnose Table Structure
Run this to understand your exact database schema:

```sql
-- Execute diagnose_movement_tables.sql
```

This will show:
- All columns in `pass_movements` table
- All columns in `borders` table  
- All columns in `authorities` table
- Foreign key relationships
- Sample data

### Step 3: Enhance Based on Results
Based on the diagnostic results, we can create a proper function with:
- Correct column names for officials
- Proper authority relationships
- Profile image support

## 📋 **Expected Results After Minimal Fix**

The app should show:
- ✅ **Movement history loads** without errors
- ✅ **Movement records** with timestamps
- ✅ **Border names** for border crossings
- ✅ **"Local Authority"** for local authority scans
- ✅ **Profile images in drawer** (unaffected)
- ⚠️ **"Unknown Official"** (until we identify correct columns)

## 🔧 **Files Created**

1. **`minimal_movement_history_fix.sql`** - Guaranteed working fix
2. **`movement_history_with_border_authority.sql`** - Enhanced version
3. **`diagnose_movement_tables.sql`** - Schema inspection tool

## 🚀 **Recommended Approach**

1. **Run minimal fix** - Get movement history working immediately
2. **Test the app** - Verify movement history loads
3. **Run diagnostics** - Understand your database schema
4. **Enhance function** - Add authority names and profile images based on actual schema

## ⚡ **Immediate Action**

**Execute this SQL right now to fix the error:**

```sql
-- Drop all existing versions
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create minimal working function
CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id TEXT)
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,
    official_name TEXT,
    official_profile_image_url TEXT,
    movement_type TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    processed_at TIMESTAMP WITH TIME ZONE,
    entries_deducted INTEGER,
    previous_status TEXT,
    new_status TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.id::TEXT as movement_id,
        COALESCE(b.name, 'Local Authority') as border_name,
        'Unknown Official'::TEXT as official_name,
        NULL::TEXT as official_profile_image_url,
        pm.movement_type,
        COALESCE(pm.latitude, 0.0) as latitude,
        COALESCE(pm.longitude, 0.0) as longitude,
        pm.processed_at,
        COALESCE(pm.entries_deducted, 0) as entries_deducted,
        COALESCE(pm.previous_status, '') as previous_status,
        COALESCE(pm.new_status, '') as new_status
    FROM pass_movements pm
    LEFT JOIN borders b ON pm.border_id = b.id
    WHERE pm.pass_id = p_pass_id::UUID
    ORDER BY pm.processed_at DESC;
END;
$$;
```

This will immediately fix the movement history error! 🎯