# Border Loading Fix

## Issue
Getting "failed to get borders for authority invalid input" error when trying to load borders for user-selectable entry/exit points.

## Root Cause
The `get_borders_for_authority` database function doesn't exist in the database, causing the RPC call to fail.

## Fixes Applied

### 1. Database Function Creation
**File**: `supabase_fix_authority_name.sql`

Added the missing `get_borders_for_authority` function:
```sql
CREATE OR REPLACE FUNCTION get_borders_for_authority(target_authority_id UUID)
RETURNS TABLE (
    border_id UUID,
    border_name TEXT,
    border_type TEXT
)
```

This function:
- Returns all active borders for a given authority
- Includes border type information
- Orders results by border name
- Has proper security and permissions

### 2. Fallback Implementation
**File**: `lib/services/pass_service.dart`

Updated `getBordersForAuthority` method to:
- Try RPC function first
- Fall back to direct table query if RPC fails
- Provide better error handling and debugging

### 3. Debug Logging
**File**: `lib/screens/pass_dashboard_screen.dart`

Added debug logging to both `_loadBordersForTemplate` methods to help troubleshoot:
- Log authority ID being queried
- Log number of borders loaded
- Log any errors that occur

## To Fix the Issue

### Option 1: Execute SQL Script (Recommended)
Run the updated `supabase_fix_authority_name.sql` script which now includes:
- Authority name fix for "Unknown Authority" error
- Missing `get_borders_for_authority` function
- Test queries to verify both functions work

### Option 2: Fallback Will Work
If the database function can't be created immediately, the fallback implementation will:
- Try the RPC function first
- Fall back to direct table query: `SELECT id, name FROM borders WHERE authority_id = ? AND is_active = true`
- This should work with existing database schema

## Expected Behavior After Fix

1. **Templates with fixed entry/exit points**: Work as before, no border loading needed
2. **Templates with user-selectable points**: 
   - Load borders when template is selected
   - Show dropdowns with available borders
   - Enable Select button only when both entry and exit are chosen

## Debug Information

Check the debug console for messages like:
- "Loading borders for authority: [uuid]"
- "Loaded X borders"
- "RPC function failed, trying direct query: [error]"

This will help identify if the issue is:
- Missing database function (RPC fails, fallback works)
- Database connection issue (both fail)
- Data issue (functions work but return no results)