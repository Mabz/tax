# Invitation Authority Migration Summary

## Changes Made

### 1. Updated RoleInvitation Model (`lib/models/role_invitation.dart`)
- Changed `countryId` field to `authorityId`
- Added `authorityName` field alongside existing `countryName` and `countryCode`
- Updated constructor, fromJson, toJson, and copyWith methods
- Added `formattedAuthority` getter that prioritizes authority name over country
- Updated toString method to show authority instead of country

### 2. Updated InvitationService (`lib/services/invitation_service.dart`)
- Fixed `getPendingInvitationsForUser()` method to properly map authority data
- Updated field mapping to use correct field names from database function
- Added proper mapping for `authority_name` and `inviter_name` fields

### 3. Updated Home Screen (`lib/screens/home_screen.dart`)
- Changed display from `invitation.formattedCountry` to `invitation.formattedAuthority`
- Fixed UI overflow issue by wrapping Column in SingleChildScrollView
- Maintained existing inviter name display logic

### 4. Database Function Already Updated
- The `get_pending_invitations_for_user()` function already returns:
  - `authority_name` - The name of the authority
  - `inviter_name` - The full name of the person who sent the invitation
  - `country_name` and `country_code` - For backward compatibility

## Expected Results

1. **Authority Display**: Invitations now show the authority name (e.g., "SARS", "ERS") instead of just country
2. **Proper Inviter**: Shows the actual name of the person who sent the invitation
3. **No UI Overflow**: Fixed the 48px overflow issue in invitation cards
4. **Backward Compatibility**: Still shows country info if authority name is not available

## Database Schema Alignment

The model now properly aligns with the authority-centric database schema:
- `role_invitations.authority_id` → `RoleInvitation.authorityId`
- `authorities.name` → `RoleInvitation.authorityName`
- `profiles.full_name` → `RoleInvitation.inviterName`

## Testing

To verify the changes work correctly:
1. Send a new invitation from an admin account
2. Check that the invitation shows the authority name (not just country)
3. Verify the inviter name shows the actual person's name
4. Confirm the invitation acceptance still works with the fixed SQL function