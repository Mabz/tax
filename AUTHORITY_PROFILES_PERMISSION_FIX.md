# Authority Profiles Permission Fix

## Issue Identified
The "User is not a country administrator" error was caused by a mismatch in how permissions were validated between the existing system and the new authority profiles system.

## Root Cause
- **Existing system**: Validates permissions by checking if user is country admin for a specific authority (passed from home screen)
- **New system**: Was trying to find a single authority_id for the user, but country admins can manage multiple authorities

## Fixes Applied

### 1. Updated AuthorityProfilesService
- Changed `getAuthorityProfiles()` to `getAuthorityProfiles(String authorityId)` to accept specific authority
- Updated `_canManageAuthority(String authorityId)` to check permissions for specific authority
- Added superuser check for broader access
- Fixed permission validation to match existing pattern

### 2. Updated ManageUsersScreen
- Added `selectedAuthority` parameter to constructor (matching existing screens)
- Updated to pass authority_id to service methods
- Updated app bar title to show authority name

### 3. Updated HomeScreen Navigation
- Modified navigation to pass authority information to ManageUsersScreen
- Follows same pattern as existing "Manage Roles" screen

## How It Works Now

### Permission Flow:
1. User selects authority in home screen drawer
2. Home screen passes authority info to ManageUsersScreen
3. ManageUsersScreen extracts authority_id and passes to service
4. Service validates user has country_administrator role for that specific authority
5. If valid, loads authority_profiles for that authority

### Validation Logic:
```sql
-- Check if user is country admin for specific authority
SELECT authority_id FROM profile_roles pr
JOIN roles r ON pr.role_id = r.id
WHERE pr.profile_id = current_user_id
AND pr.authority_id = target_authority_id
AND pr.is_active = true
AND r.name = 'country_administrator'
```

## Testing Steps

### 1. Run Debug Queries
Execute `debug_authority_profiles_permissions.sql` to check:
- Your current roles and authorities
- Whether you have country_administrator role
- What authority_profiles you should be able to see
- RLS policy status

### 2. Test the App
1. **Hot restart** your Flutter app
2. **Login as country administrator**
3. **Select an authority** in the drawer (if you manage multiple)
4. **Go to "Manage Users"** - should now work without permission error
5. **Verify you see authority users** from that specific authority

### 3. Expected Behavior
- Should see users who have roles in the selected authority
- Should be able to edit display names, active status, and notes
- Should see proper authority name in the app bar title

## Troubleshooting

### If you still get permission errors:
1. **Check your roles**: Run the debug queries to verify you have country_administrator role
2. **Check authority selection**: Make sure you have an authority selected in the home screen drawer
3. **Check RLS policies**: Verify the policies are active and working correctly

### If you see no users:
1. **Check authority_profiles table**: `SELECT COUNT(*) FROM authority_profiles WHERE authority_id = 'your-authority-id'`
2. **Check if migration worked**: The setup should have created authority_profiles for existing users
3. **Try creating a new role assignment**: Send an invitation and accept it to test the trigger

### If function errors occur:
1. **Check function exists**: `SELECT * FROM information_schema.routines WHERE routine_name = 'get_authority_profiles_for_admin'`
2. **Check function permissions**: `GRANT EXECUTE ON FUNCTION get_authority_profiles_for_admin TO authenticated`

## Key Changes Summary

✅ **Fixed permission validation** to match existing system pattern  
✅ **Added authority-specific access control** instead of trying to find single authority  
✅ **Updated UI to show authority context** in title and navigation  
✅ **Maintained consistency** with existing "Manage Roles" screen pattern  
✅ **Added superuser support** for broader access when needed  

The system now properly validates permissions and should work exactly like the existing "Manage Roles" screen! 🎉