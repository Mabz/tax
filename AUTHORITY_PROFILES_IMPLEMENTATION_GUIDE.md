# Authority Profiles Implementation Guide

## Overview
This implementation creates an `authority_profiles` table that allows country administrators to manage authority users without direct access to their profiles. The system integrates with the existing invitation workflow.

## What's Been Created

### 1. Database Schema (`create_authority_profiles_system.sql`)
- **authority_profiles table**: Links authorities to profiles with management fields
- **Automatic triggers**: Creates authority_profiles when roles are assigned
- **RLS policies**: Ensures proper access control
- **Database functions**: For querying and updating authority profiles
- **Data migration**: Populates existing users into the new system

### 2. Flutter Service (`lib/services/authority_profiles_service.dart`)
- **AuthorityProfile model**: Represents authority profile data
- **AuthorityProfilesService**: Handles all authority profile operations
- **Real-time updates**: Stream support for live data

### 3. UI Screen (`lib/screens/manage_users_screen.dart`)
- **Manage Users interface**: Replaces the old "Manage Users" screen
- **Edit functionality**: Allows updating display names, active status, and notes
- **User-friendly design**: Shows profile info, roles, and management options

## Implementation Steps

### Step 1: Apply Database Changes
```sql
-- Run this in your Supabase SQL editor
-- File: create_authority_profiles_system.sql
```

### Step 2: Update Navigation/Routing
You need to update your app's navigation to:

1. **Rename existing "Manage Users" to "Manage Roles"**
2. **Add new "Manage Users" that uses the new screen**

Example routing update:
```dart
// In your navigation/routing file
case '/manage-roles': // Renamed from /manage-users
  return MaterialPageRoute(
    builder: (context) => const ManageRolesScreen(), // Your existing screen
  );

case '/manage-users': // New route
  return MaterialPageRoute(
    builder: (context) => const ManageUsersScreen(), // New authority profiles screen
  );
```

### Step 3: Update Menu/Navigation UI
Update your admin menu to show both options:

```dart
// Example menu items
ListTile(
  leading: const Icon(Icons.admin_panel_settings),
  title: const Text('Manage Roles'),
  subtitle: const Text('Assign roles and send invitations'),
  onTap: () => Navigator.pushNamed(context, '/manage-roles'),
),
ListTile(
  leading: const Icon(Icons.people),
  title: const Text('Manage Users'),
  subtitle: const Text('Manage authority user profiles'),
  onTap: () => Navigator.pushNamed(context, '/manage-users'),
),
```

### Step 4: Import New Files
Add these imports where needed:

```dart
import 'services/authority_profiles_service.dart';
import 'screens/manage_users_screen.dart';
```

## How It Works

### Invitation Flow Integration
1. **Existing flow remains unchanged**: Country admin sends invitation via role_invitations
2. **User accepts invitation**: profile_roles record created as before
3. **Automatic trigger**: authority_profiles record created automatically
4. **Country admin management**: Can now manage the authority_profile record

### Authority Profile Management
- **Display Name**: Country admin can set custom names for users
- **Active Status**: Enable/disable users without affecting their actual profiles
- **Notes**: Add administrative notes about users
- **Role Information**: View assigned roles (read-only)
- **Profile Information**: View basic profile info (read-only)

### Security
- **RLS policies**: Ensure country admins can only manage their authority's users
- **No direct profile access**: Admins cannot modify actual user profiles
- **Audit trail**: Tracks who assigned users and when

## Database Schema Details

### authority_profiles Table
```sql
- id: Primary key
- authority_id: Links to authorities table
- profile_id: Links to profiles table  
- display_name: Customizable name (managed by country admin)
- is_active: Enable/disable flag (managed by country admin)
- assigned_by: Who created this authority profile
- assigned_at: When it was created
- notes: Optional admin notes
- created_at/updated_at: Timestamps
```

### Key Functions
- `get_authority_profiles_for_admin()`: Returns all authority profiles for an admin
- `update_authority_profile()`: Updates display name, active status, and notes
- `create_authority_profile_on_role_assignment()`: Auto-creates profiles on role assignment

## Testing the Implementation

### 1. Verify Database Setup
```sql
-- Check if table exists
SELECT * FROM public.authority_profiles LIMIT 5;

-- Check if existing users were migrated
SELECT COUNT(*) FROM public.authority_profiles;
```

### 2. Test the UI
1. Login as a country administrator
2. Navigate to "Manage Users"
3. Verify you can see existing authority users
4. Test editing a user's display name and notes
5. Test enabling/disabling a user

### 3. Test Integration
1. Send a new role invitation
2. Have the user accept it
3. Verify the authority_profile is created automatically
4. Verify it appears in the Manage Users screen

## Migration Notes

- **Existing users**: All current authority users are automatically migrated to authority_profiles
- **Backward compatibility**: The existing profile.authority_id field remains for compatibility
- **No data loss**: All existing functionality continues to work
- **Gradual transition**: You can implement this alongside existing systems

## Next Steps

After implementing this system, you may want to:

1. **Update other screens**: Modify screens that display user names to use authority_profiles.display_name
2. **Add bulk operations**: Implement bulk enable/disable functionality
3. **Enhanced filtering**: Add filters for active/inactive users, roles, etc.
4. **Export functionality**: Add ability to export user lists
5. **User activity tracking**: Integrate with the last_active_at field (when implemented)

## Troubleshooting

### Common Issues
1. **Permission errors**: Ensure RLS policies are correctly applied
2. **Missing authority_profiles**: Check if triggers are working correctly
3. **UI not loading**: Verify the user has country_administrator role

### Debug Queries
```sql
-- Check user's roles
SELECT pr.*, r.name 
FROM profile_roles pr 
JOIN roles r ON pr.role_id = r.id 
WHERE pr.profile_id = 'user-id-here';

-- Check authority_profiles for an authority
SELECT * FROM authority_profiles WHERE authority_id = 'authority-id-here';
```