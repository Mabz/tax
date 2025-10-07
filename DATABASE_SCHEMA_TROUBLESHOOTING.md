# Database Schema Troubleshooting - Movement History

## ❌ **Current Error**
```
column pm.processed_by does not exist
Perhaps you meant to reference the column "pm.processed_at"
```

## 🔍 **Root Cause**
The SQL function assumes a `processed_by` column exists in the `pass_movements` table, but it doesn't. We need to identify the correct column names for:
- Official who processed the movement
- Profile image relationships

## ✅ **Immediate Fix**

### Step 1: Run Basic Function (Works Now)
Execute this SQL to get movement history working immediately:

```sql
-- Run the contents of simple_movement_history_fix.sql
```

This creates a basic function that:
- ✅ **Works immediately** - No column dependencies
- ✅ **Shows authority names** - Real authority names instead of "Local Authority"
- ⚠️ **Placeholder for profiles** - Shows "Unknown Official" until we fix the schema

### Step 2: Check Table Structure
Run this to see the actual table structure:

```sql
-- Run the contents of check_pass_movements_table_structure.sql
```

This will show:
- All columns in the `pass_movements` table
- Data types and constraints
- Foreign key relationships

## 🔧 **Complete Fix (After Schema Check)**

Once we know the correct column names, we can update the function. Common possibilities:

### Option A: If column is `official_id`
```sql
LEFT JOIN profiles p ON pm.official_id = p.id
```

### Option B: If column is `scanned_by`
```sql
LEFT JOIN profiles p ON pm.scanned_by = p.id
```

### Option C: If column is `user_id`
```sql
LEFT JOIN profiles p ON pm.user_id = p.id
```

## 📋 **Expected Table Structure**

The `pass_movements` table likely has columns like:
```sql
- id (UUID)
- pass_id (UUID)
- movement_type (TEXT)
- processed_at (TIMESTAMP)
- latitude (DOUBLE PRECISION)
- longitude (DOUBLE PRECISION)
- entries_deducted (INTEGER)
- previous_status (TEXT)
- new_status (TEXT)
- border_id (UUID) -- Foreign key to borders
- authority_id (UUID) -- Foreign key to authorities
- [official_column] (UUID) -- Foreign key to profiles (unknown name)
```

## 🧪 **Testing Steps**

### 1. Run the Simple Fix
```sql
-- Execute simple_movement_history_fix.sql
```

### 2. Test Movement History
The app should now load movement history without errors, showing:
- ✅ Movement records
- ✅ Real authority names
- ⚠️ "Unknown Official" (temporary)

### 3. Check Schema
```sql
-- Execute check_pass_movements_table_structure.sql
```

### 4. Update Function (Once Schema is Known)
Based on the schema results, update the function to include proper profile joins.

## 🎯 **Expected Results**

After the simple fix:
- ✅ **No more database errors**
- ✅ **Movement history loads**
- ✅ **Authority names show correctly**
- ✅ **Profile images in drawer work**
- ⚠️ **Movement profile images pending** (until schema is fixed)

## 📁 **Files Created**

1. `simple_movement_history_fix.sql` - Immediate working fix
2. `check_pass_movements_table_structure.sql` - Schema inspection
3. `fix_movement_history_without_processed_by.sql` - Advanced fix (when schema is known)

## 🚀 **Next Steps**

1. **Run the simple fix** - Gets movement history working immediately
2. **Check the schema** - Identify correct column names
3. **Update function** - Add profile image support once schema is known
4. **Test complete functionality** - Verify all features work

The movement history should work immediately after running the simple fix! 🎯