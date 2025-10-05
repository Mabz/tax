# Real-time Secure Code Updates Fix

## Problem
Secure codes are generated when Border Control processes passes, but users have to refresh the "My Passes" screen to see them. The secure codes should appear automatically in real-time.

## Root Cause
1. **Missing Database Columns**: The `secure_code` and `secure_code_expires_at` columns were missing from the `purchased_passes` table
2. **Disabled Real-time Subscriptions**: Real-time subscriptions were disabled in the pass dashboard
3. **Incomplete Real-time Setup**: The database wasn't properly configured for real-time updates

## Solution

### 1. Database Setup
Run these SQL scripts in Supabase SQL Editor:

```sql
-- 1. Add secure code columns and setup real-time
\i add_secure_code_columns_and_realtime.sql

-- 2. Test the functionality
\i test_secure_code_realtime.sql

-- 3. Run real-time tests
\i test_realtime_updates.sql
```

### 2. Frontend Updates
The following files have been updated:

- **lib/services/pass_service.dart**: Enhanced real-time subscription with secure code focus
- **lib/screens/pass_dashboard_screen.dart**: Re-enabled real-time subscriptions with secure code notifications

### 3. Key Changes Made

#### Database Changes:
- ✅ Added `secure_code` column to `purchased_passes` table
- ✅ Added `secure_code_expires_at` column to `purchased_passes` table  
- ✅ Set `REPLICA IDENTITY FULL` for complete real-time updates
- ✅ Created `generate_secure_code_for_pass()` function
- ✅ Created `verify_secure_code()` function
- ✅ Updated `process_pass_movement()` to generate secure codes
- ✅ Added real-time trigger for secure code updates

#### Frontend Changes:
- ✅ Re-enabled real-time subscriptions in pass dashboard
- ✅ Enhanced real-time subscription to handle secure code updates
- ✅ Added user notifications when secure codes are updated
- ✅ Improved error handling and debugging

## How It Works Now

1. **Border Control Processing**: When border control scans a pass, `process_pass_movement()` is called
2. **Secure Code Generation**: The function automatically generates a 3-digit secure code with 15-minute expiry
3. **Database Update**: The `purchased_passes` table is updated with the secure code
4. **Real-time Notification**: Supabase sends a real-time update to the user's device
5. **UI Update**: The "My Passes" screen automatically shows the secure code
6. **User Notification**: A green snackbar appears saying "Secure code updated"

## Testing

### Manual Testing:
1. Open the Flutter app and go to "My Passes" screen
2. Keep the app open and visible
3. In Supabase SQL Editor, run:
   ```sql
   SELECT manual_generate_secure_code('your-pass-id-here');
   ```
4. Watch the app - the secure code should appear automatically within 1-2 seconds

### Automated Testing:
```sql
-- Test the complete functionality
SELECT test_secure_code_functionality();

-- Check current secure codes
SELECT * FROM check_secure_codes();

-- Run real-time tests
\i test_realtime_updates.sql
```

## Debugging

If real-time updates aren't working:

1. **Check Flutter Console**: Look for debug messages starting with `🔄`
2. **Check Database**: Verify columns exist with `\d purchased_passes`
3. **Test Functions**: Run `SELECT test_secure_code_functionality();`
4. **Check Supabase Dashboard**: Verify real-time is enabled for the project

## Expected Behavior

- ✅ Secure codes appear automatically without refresh
- ✅ Green notification when secure code is updated
- ✅ Secure codes expire after 15 minutes
- ✅ Real-time updates work for all pass changes
- ✅ Fallback to manual refresh if real-time fails

## Tables Involved in Real-time Updates

1. **`purchased_passes`** - Main table storing secure codes (REPLICA IDENTITY FULL)
2. **`pass_movements`** - Triggers secure code generation when passes are processed
3. **`pass_processing_audit`** - Audit trail (optional, for logging)

The real-time subscription specifically listens to `purchased_passes` table changes filtered by `profile_id` to ensure users only get updates for their own passes.