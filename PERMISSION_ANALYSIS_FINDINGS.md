# Permission Analysis: How Country Administrators Access Management Functions

## Key Findings

### 🎯 **Root Cause Identified**
The issue is NOT with individual screen permissions, but with how the **drawer menu visibility** is determined vs. how our **authority profiles service** validates permissions.

## How Existing Screens Work

### 1. **Drawer Menu Visibility**
The Authority Management section (including Manage Authority, Manage Borders, Border Officials) is shown when:

```dart
if (_isSuperuser || (_selectedAuthority != null && _isCountryAdminForSelected()))
```

Where `_isCountryAdminForSelected()` checks:
```dart
bool _isCountryAdminForSelected() {
    return _hasCountryRole(AppConstants.roleCountryAdmin);
}

bool _hasCountryRole(String roleName) {
    return _currentCountryRoles.contains(roleName);
}
```

### 2. **How _currentCountryRoles is Populated**
When an authority is selected, `_loadAuthorityCountryRoles()` is called:

```dart
final roles = await RoleService.getUserRolesForCountry(_selectedAuthority!.countryId);
setState(() {
    _currentCountryRoles = roles;
});
```

### 3. **RoleService.getUserRolesForCountry() Logic**
This method queries:
```sql
SELECT roles.name 
FROM profile_roles pr
JOIN roles ON pr.role_id = roles.id
JOIN authorities ON pr.authority_id = authorities.id
WHERE pr.profile_id = current_user_id
AND authorities.country_id = target_country_id
AND pr.is_active = true
```

## How Individual Screens Handle Permissions

### 1. **SingleAuthorityManagementScreen** (Manage Authority)
- **Navigation**: Passes `Authority` object directly
- **Permission Check**: Uses `RoleService.isSuperuser()` OR `RoleService.hasAdminRole()`
- **Key**: `hasAdminRole()` checks if user has country_administrator role for ANY authority

### 2. **BorderManagementScreen** (Manage Borders)  
- **Navigation**: Passes `selectedCountry` map with authority info
- **Permission Check**: Uses `RoleService.isSuperuser()` OR `RoleService.hasAdminRole()`
- **Authority Loading**: Uses `AuthorityService.getAdminAuthorities()` for country admins

### 3. **BorderOfficialManagementScreen** (Border Officials)
- **Navigation**: Passes `selectedCountry` map with authority info  
- **Permission Check**: **NO explicit permission check in initState!**
- **Relies on**: Drawer visibility and service-level permissions

## The Problem with Our Authority Profiles Service

### ❌ **Current Logic (Too Restrictive)**
```dart
// Check if user is country administrator for this specific authority
final response = await _supabase
    .from('profile_roles')
    .select('authority_id, roles!inner(name)')
    .eq('profile_id', userId)
    .eq('authority_id', authorityId)  // ← This is the problem!
    .eq('is_active', true)
    .eq('roles.name', 'country_administrator')
    .maybeSingle();
```

### ✅ **Should Be (Like Other Screens)**
```dart
// Check if user has country_administrator role for the authority's country
final isSuperuser = await RoleService.isSuperuser();
if (isSuperuser) return true;

final hasAdminRole = await RoleService.hasAdminRole();
return hasAdminRole;
```

## Why This Matters

### **The Mismatch:**
1. **Drawer shows menu items** when user has country_administrator role for the **country** (via `getUserRolesForCountry`)
2. **Our service validates** if user has country_administrator role for the **specific authority**
3. **Other screens validate** if user has country_administrator role for **any authority** (via `hasAdminRole`)

### **The Issue:**
- A country administrator might have roles for **multiple authorities** in the same country
- The drawer shows items because they have country_administrator for the **country**
- Our service fails because we're checking for the **specific authority** instead of the **country**

## The Fix

We need to align our permission validation with the existing pattern used by other management screens:

```dart
Future<bool> _canManageAuthority(String authorityId) async {
    try {
        // Check if user is superuser
        final isSuperuser = await RoleService.isSuperuser();
        if (isSuperuser) return true;

        // Check if user has admin role (like other screens do)
        final hasAdminRole = await RoleService.hasAdminRole();
        return hasAdminRole;
    } catch (e) {
        return false;
    }
}
```

OR, if we want to be more specific to the country:

```dart
Future<bool> _canManageAuthority(String authorityId) async {
    try {
        // Get the authority's country
        final authority = await AuthorityService.getAuthorityById(authorityId);
        if (authority?.countryId == null) return false;

        // Check roles for that country (like the drawer does)
        final roles = await RoleService.getUserRolesForCountry(authority.countryId);
        return roles.contains(AppConstants.roleCountryAdmin);
    } catch (e) {
        return false;
    }
}
```

## Summary

The existing screens work because they use **broad permission checks** (`hasAdminRole()`) rather than **specific authority checks**. Our service was being too restrictive by checking for the exact authority instead of following the established pattern.

**The drawer visibility and screen permissions should match** - if the drawer shows the menu item, the screen should be accessible! 🎯