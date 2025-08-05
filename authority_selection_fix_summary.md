# Authority Selection Fix for Country Admins

## Issue Identified

The authority selection dropdown was not visible for country admins due to a bug in the `get_admin_authorities()` database function.

### Root Cause

In the `get_admin_authorities()` function, the WHERE clause had an incorrect condition:

```sql
-- INCORRECT (was checking country_id against authority_id)
a.country_id IN (
  SELECT DISTINCT pr.authority_id
  FROM profile_roles pr
  ...
)
```

This was wrong because:
- `pr.authority_id` contains authority IDs (not country IDs)
- `a.country_id` contains country IDs
- The comparison was checking if a country ID exists in a list of authority IDs

### The Fix

Updated the function to correctly check:

```sql
-- CORRECT (checking authority_id against authority_id)
a.id IN (
  SELECT DISTINCT pr.authority_id
  FROM profile_roles pr
  ...
)
```

## Changes Made

### 1. Fixed Database Function (`fix_get_admin_authorities_function.sql`)
- Corrected the WHERE clause logic
- Added support for both country_admin and country_auditor roles
- Added `a.is_active = true` filter to only show active authorities
- Improved the function structure and comments

### 2. Enhanced Debug Logging (`lib/screens/home_screen.dart`)
- Added debug logging in `_loadAuthorities()` to show loaded authorities
- Added debug logging in `_buildDrawer()` to show authority selection visibility logic
- Added authority details logging to help troubleshoot

## Expected Behavior After Fix

### For Country Admins:
1. **Authority Selection Visible**: The "Select Authority" dropdown will appear in the drawer
2. **Filtered Authorities**: Only authorities they have admin access to will be shown
3. **Automatic Selection**: First authority will be auto-selected if none is chosen

### For Country Auditors:
1. **Authority Selection Visible**: Same as country admins
2. **Filtered Authorities**: Only authorities they have auditor access to will be shown

### For Superusers:
1. **All Authorities**: Can see and select from all active authorities (unchanged)

## Testing Steps

1. **Apply the SQL Fix**: Run `fix_get_admin_authorities_function.sql` in Supabase
2. **Test Country Admin**: 
   - Login as a country admin
   - Check that authority selection dropdown appears
   - Verify only assigned authorities are shown
3. **Test Country Auditor**: Same as country admin
4. **Test Superuser**: Verify all authorities still appear

## Debug Information

The debug logs will show:
- `🎯 Drawer build - Superuser: false, Country Admin: true, Country Auditor: false`
- `🎯 Authorities count: X` (should be > 0 for country admins)
- `🎯 Should show authority selection: true` (should be true for country admins)
- `🌍 Loaded X assigned authorities for admin/auditor`
- Individual authority details

## Database Requirements

The fix assumes:
- `profile_roles` table has `authority_id` field (not `country_id`)
- Users have role assignments with `authority_id` pointing to specific authorities
- The `is_superuser()` and `user_has_role()` 