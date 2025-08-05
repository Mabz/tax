# Authority Dropdown Debugging Guide

## Current Issue
Country admin users are not seeing the authority selection dropdown in the drawer.

## Debugging Steps

### 1. Check Flutter Debug Console
When a country admin logs in, look for these debug messages:

```
🔍 Starting role check for current user...
👤 Current user ID: [user-id]
📧 Current user email: [email]
🎭 All user roles: [list of roles]
🔑 Superuser check: false
🌍 Country Admin check: [should be true]
🔍 Country Auditor check: false
🎯 Should load authorities: [should be true]
✅ Loading authorities...
🏛️ _loadAuthorities called - isLoading: false
🔍 Loading authorities - Superuser: false, Country Admin: true, Country Auditor: false
🔍 Loading admin authorities for country admin/auditor...
🌍 Loaded X assigned authorities for admin/auditor
📋 Authority details:
  - [Authority Name] ([Code]) - [Country]
🎯 Drawer build - Superuser: false, Country Admin: true, Country Auditor: false
🎯 Authorities count: X
🎯 Should show authority selection: true
```

### 2. Test Database Functions
Run the `test_authority_functions.sql` script in Supabase SQL editor to check:

1. **Profile Roles**: Does the user have active country_admin role assignments?
2. **user_has_role Function**: Does it return true for country_admin?
3. **get_admin_authorities Function**: Does it return authorities for the user?

### 3. Use Debug Button
A temporary debug button has been added to the drawer that shows:
- Current role states (S:false CA:true AU:false)
- Authority count (Auth:X)
- Allows manual testing of authority loading

### 4. Common Issues to Check

#### Issue 1: Role Detection Failing
**Symptoms**: `Country Admin check: false` in logs
**Causes**:
- User doesn't have country_admin role in profile_roles table
- profile_roles.is_active is false
- user_has_role function is not working

**Fix**: Check profile_roles table and ensure user has active country_admin role

#### Issue 2: Authority Function Not Working
**Symptoms**: `Country Admin check: true` but `Loaded 0 assigned authorities`
**Causes**:
- get_admin_authorities function has bugs
- User's profile_roles.authority_id doesn't match any authorities
- Authorities are inactive (is_active = false)

**Fix**: Apply the `fix_get_admin_authorities_function.sql` fix

#### Issue 3: UI Condition Failing
**Symptoms**: Authorities loaded but dropdown not visible
**Causes**:
- UI condition `(_isSuperuser || _isCountryAdmin || _isCountryAuditor) && _authorities.isNotEmpty` is false
- State not updated properly

**Fix**: Check drawer debug logs for condition evaluation

### 5. Manual Database Checks

#### Check User's Profile Roles
```sql
SELECT 
  pr.profile_id,
  pr.role_id,
  pr.authority_id,
  pr.is_active,
  r.name as role_name,
  a.name as authority_name
FROM profile_roles pr
JOIN roles r ON r.id = pr.role_id
JOIN authorities a ON a.id = pr.authority_id
WHERE pr.profile_id = '[user-id]'
AND pr.is_active = true;
```

#### Check Authority Function
```sql
SELECT * FROM get_admin_authorities();
```

### 6. Expected Flow for Country Admin

1. **Login** → Role check runs
2. **Role Detection** → `_isCountryAdmin = true`
3. **Authority Loading** → `_loadAuthorities()` called
4. **Database Query** → `get_admin_authorities()` returns authorities
5. **UI Update** → `_authorities.isNotEmpty = true`
6. **Drawer Build** → Authority selection visible

### 7. Quick Fixes to Try

#### Fix 1: Apply SQL Fix
```sql
-- Run fix_get_admin_authorities_function.sql
```

#### Fix 2: Check Profile Roles
Ensure the country admin user has:
- Active profile_roles record
- role_id pointing to country_admin role
- authority_id pointing to valid authority
- is_active = true

#### Fix 3: Restart App
Sometimes state doesn't update properly - restart the Flutter app

### 8. If Still Not Working

1. **Share Debug Logs**: Copy all debug output from Flutter console
2. **Run SQL Tests**: Share results from `test_authority_functions.sql`
3. **Check Database**: Verify profile_roles and authorities tables have correct data

The debug button and enhanced logging should help identify exactly where the issue is occurring.