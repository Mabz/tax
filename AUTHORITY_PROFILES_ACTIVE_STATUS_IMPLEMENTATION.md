# Authority Profiles Active Status Implementation

## Overview
This implementation ensures that when a user is disabled in the `authority_profiles` table (`is_active = false`), they are completely hidden from all authority-related functionality including:

1. **Manage Roles screen** - Won't show disabled users
2. **Border Officials screen** - Won't show disabled border officials  
3. **Border Assignments** - Won't show assignments for disabled users
4. **Authority dropdown** - Disabled users won't see authorities they're disabled for

## Files to Execute

### 1. Core Functions Update
**File:** `update_all_functions_respect_authority_profiles_active_status.sql`

This file updates all the key functions to respect `authority_profiles.is_active`:

- `get_profiles_by_authority_enhanced` - Only shows active authority profiles in Manage Roles
- `get_border_officials_for_authority_enhanced` - Only shows active border officials
- `get_border_officials_by_authority_enhanced` - Only shows active border officials in dropdowns
- `get_border_assignments_with_permissions_by_authority` - Only shows assignments for active users
- `get_border_assignments_with_permissions` - Country-based version with same filtering
- `get_admin_authorities_for_user` - Only shows authorities where user is active

### 2. Automatic Authority Profiles Creation
**File:** `create_authority_profiles_trigger_on_invitation_acceptance.sql`

This file creates:

- **Trigger function** that automatically creates `authority_profiles` entries when role invitations are accepted
- **Database trigger** on `profile_roles` table to call the function
- **Updated `accept_role_invitation` function** to ensure proper invitation processing
- **Performance indexes** for better query performance

### 3. Service Updates
**File:** `lib/services/authority_service.dart` (already updated)

Updated `getAdminAuthorities()` method to use the new `get_admin_authorities_for_user` function that respects `authority_profiles.is_active`.

## How It Works

### When Role Invitation is Accepted:
1. User accepts invitation via `accept_role_invitation` function
2. `profile_roles` record is created
3. **Trigger automatically fires** and creates `authority_profiles` record with:
   - `profile_id` from the new profile_roles record
   - `authority_id` from the new profile_roles record  
   - `display_name` set to user's `full_name` initially
   - `is_active` set to `true` by default
   - `assigned_by` and `assigned_at` from the profile_roles record

### When User is Disabled:
1. Country admin sets `is_active = false` in `authority_profiles` via Manage Users screen
2. User immediately disappears from:
   - Manage Roles screen
   - Border Officials screen
   - Border Assignments
   - Authority dropdown (when they log in)

### When User is Re-enabled:
1. Country admin sets `is_active = true` in `authority_profiles` via Manage Users screen
2. User immediately reappears in all relevant screens

## Database Schema Impact

### New Indexes Added:
```sql
-- For faster lookups by profile and authority
CREATE INDEX idx_authority_profiles_profile_authority 
ON authority_profiles(profile_id, authority_id);

-- For faster filtering by active status
CREATE INDEX idx_authority_profiles_is_active 
ON authority_profiles(is_active) WHERE is_active = true;
```

### Trigger Added:
```sql
-- Automatically creates authority_profiles when profile_roles is created
CREATE TRIGGER trigger_create_authority_profile_on_role_assignment
    AFTER INSERT ON profile_roles
    FOR EACH ROW
    EXECUTE FUNCTION create_authority_profile_on_role_assignment();
```

## Testing Steps

1. **Execute the SQL files** in this order:
   - `update_all_functions_respect_authority_profiles_active_status.sql`
   - `create_authority_profiles_trigger_on_invitation_acceptance.sql`

2. **Test invitation flow**:
   - Send a role invitation to a new user
   - Have them accept the invitation
   - Verify `authority_profiles` record is created automatically
   - Verify user appears in Manage Roles and other screens

3. **Test disable functionality**:
   - Go to Manage Users screen
   - Set a user's `is_active` to `false`
   - Verify user disappears from Manage Roles screen
   - Verify user disappears from Border Officials screen
   - Have that user log in and verify they don't see the authority in dropdown

4. **Test re-enable functionality**:
   - Set user's `is_active` back to `true`
   - Verify user reappears in all screens

## Benefits

1. **Consistent User Management**: Country admins have full control over user visibility
2. **Security**: Disabled users can't access authority functions even if they have valid profile_roles
3. **Automatic Setup**: New users get authority_profiles records automatically
4. **Performance**: Optimized queries with proper indexes
5. **Clean UI**: Disabled users don't clutter management interfaces

## Migration Notes

For existing users who don't have `authority_profiles` records yet, you may want to run a one-time migration:

```sql
-- Create authority_profiles for existing profile_roles (one-time migration)
INSERT INTO authority_profiles (profile_id, authority_id, display_name, is_active, assigned_by, assigned_at)
SELECT DISTINCT 
    pr.profile_id,
    pr.authority_id,
    p.full_name,
    true,
    pr.assigned_by_profile_id,
    pr.assigned_at
FROM profile_roles pr
JOIN profiles p ON pr.profile_id = p.id
WHERE pr.is_active = true
AND NOT EXISTS (
    SELECT 1 FROM authority_profiles ap 
    WHERE ap.profile_id = pr.profile_id 
    AND ap.authority_id = pr.authority_id
);
```