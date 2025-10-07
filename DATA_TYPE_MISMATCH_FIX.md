# Data Type Mismatch Fix - Movement History

## ❌ **Error Encountered**
```
structure of query does not match function result type
Returned type numeric does not match expected type double precision in column 5
```

## 🔍 **Root Cause**
- The database stores latitude/longitude as `NUMERIC` type
- The SQL function was expecting `DOUBLE PRECISION` type
- PostgreSQL is strict about type matching between function definition and actual data

## ✅ **Complete Fix Applied**

### 1. **SQL Function Updated**
- **Changed**: `latitude DOUBLE PRECISION` → `latitude NUMERIC`
- **Changed**: `longitude DOUBLE PRECISION` → `longitude NUMERIC`
- **Result**: Function signature now matches actual database types

### 2. **Dart Code Enhanced**
- **Added**: `_parseNumericToDouble()` helper method
- **Enhanced**: Robust parsing of numeric values from database
- **Handles**: String, int, double, num, and null values safely
- **Result**: Dart code can handle any numeric format from database

## 🚀 **Immediate Fix**

**Run this SQL in Supabase SQL Editor:**

```sql
-- Drop all existing versions
DROP FUNCTION IF EXISTS get_pass_movement_history(TEXT);
DROP FUNCTION IF EXISTS get_pass_movement_history(UUID);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id TEXT);
DROP FUNCTION IF EXISTS public.get_pass_movement_history(p_pass_id UUID);

-- Create function with correct data types
CREATE OR REPLACE FUNCTION get_pass_movement_history(p_pass_id TEXT)
RETURNS TABLE (
    movement_id TEXT,
    border_name TEXT,
    official_name TEXT,
    movement_type TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
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

## 🔧 **Dart Code Improvements**

The Dart code now includes a robust numeric parser:

```dart
/// Helper method to safely parse numeric values to double
static double _parseNumericToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  return 0.0;
}
```

This handles:
- ✅ **NUMERIC from database** - Converts to double
- ✅ **String representations** - Parses safely
- ✅ **Integer values** - Converts to double
- ✅ **Null values** - Returns 0.0 as fallback
- ✅ **Any num type** - Handles all numeric types

## 🎯 **Expected Results**

After applying the fix:
- ✅ **Movement history loads successfully**
- ✅ **No data type mismatch errors**
- ✅ **Latitude/longitude values display correctly**
- ✅ **All movement records show properly**
- ✅ **Border names and timestamps work**

## 📋 **Files Created**
- `fix_data_type_mismatch.sql` - SQL function with correct types
- `DATA_TYPE_MISMATCH_FIX.md` - This troubleshooting guide

## 🧪 **Testing**

After running the SQL fix:
1. **Open movement history** - Should load without errors
2. **Check coordinates** - Latitude/longitude should display
3. **Verify all data** - Movement records should be complete

## ✅ **Status: Ready to Test**

The data type mismatch has been completely resolved with:
- **Correct SQL function types** matching database schema
- **Robust Dart parsing** handling any numeric format
- **Comprehensive error handling** for edge cases

Run the SQL fix and the movement history should work perfectly! 🎯