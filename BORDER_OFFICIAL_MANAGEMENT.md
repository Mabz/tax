# Enhanced Border Official Management System

## Overview

This document describes the enhanced border official management system that allows border officials to process passes based on their specific border assignments and authority permissions.

## Key Features

### 1. Border-Specific Assignments
- Border officials can be assigned to specific borders within their authority
- Each assignment is tracked with assignment date, assigned by user, and active status
- Officials can be assigned to multiple borders
- Assignments can be activated/deactivated without deletion

### 2. Pass Processing Rules

Border officials can process passes under the following conditions:

#### For Passes with Specific Border Assignment
- **Border Officials**: Can process passes ONLY if they are specifically assigned to that border
- **Country Admins/Superusers**: Can process passes for any border within their authority

#### For General Authority Passes (no specific border)
- **Border Officials**: Can process general passes for their authority
- **Country Admins/Superusers**: Can process any general pass for their authority

#### Authority Validation
- Border officials must belong to the same authority that issued the pass
- Local authorities can process passes from any authority within their country

## Database Schema

### border_assignments Table
```sql
CREATE TABLE border_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id),
    border_id UUID NOT NULL REFERENCES borders(id),
    assigned_by UUID REFERENCES profiles(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## API Functions

### assign_official_to_border(profile_id, border_id, notes)
- Assigns a border official to a specific border
- Validates that the assigner has appropriate permissions
- Validates that the target profile is a border official in the correct authority
- Deactivates any existing assignment before creating a new one

### revoke_official_from_border(profile_id, border_id)
- Revokes a border official's assignment from a border
- Sets the assignment to inactive rather than deleting it
- Maintains audit trail of assignments

### get_assigned_borders(country_id)
- Returns all border assignments for a country
- Includes border details, official information, and assignment metadata
- Filtered by user's authority permissions

### get_border_officials_for_country(country_id)
- Returns all border officials in a country with their assignment counts
- Shows which borders each official is assigned to
- Only accessible to country admins and superusers

## Service Layer

### BorderOfficialService Methods

#### canOfficialProcessBorder(profileId, borderId)
- Checks if a specific border official can process passes for a border
- Returns true if the official is assigned to the border

#### getAssignedBordersForOfficial(profileId)
- Returns all borders assigned to a specific border official
- Includes border details and metadata

#### canProcessAllAuthorityBorders(authorityId)
- Checks if the current user has admin privileges for all borders in an authority
- Returns true for country admins and superusers

## UI Integration

### Authority Validation Screen
The authority validation screen now includes enhanced logic:

1. **Pass Authority Validation**: Verifies the pass was issued by the correct authority
2. **Border Assignment Check**: For border-specific passes, validates the official is assigned to that border
3. **Admin Override**: Country admins and superusers can process any pass in their authority
4. **Clear Error Messages**: Provides specific feedback when access is denied

### Border Official Management Screen
- View all border officials in a country
- See their current border assignments
- Assign/revoke border access
- Track assignment history

## Security Features

### Row Level Security (RLS)
- Users can only view assignments for borders in their authority
- Only country admins and superusers can manage assignments
- All operations are logged with user attribution

### Permission Validation
- All functions validate user permissions before executing
- Border officials must belong to the correct authority
- Assignment operations require admin privileges

## Usage Examples

### Assigning a Border Official
```dart
await BorderOfficialService.assignOfficialToBorder(
  'official-profile-id',
  'border-id',
);
```

### Checking Border Access
```dart
final canProcess = await BorderOfficialService.canOfficialProcessBorder(
  'official-profile-id',
  'border-id',
);
```

### Getting Official's Assigned Borders
```dart
final borders = await BorderOfficialService.getAssignedBordersForOfficial(
  'official-profile-id',
);
```

## Migration Notes

### Existing Systems
- The system is backward compatible with existing border official roles
- Officials without specific border assignments can still process general authority passes
- Country admins retain full access to all borders in their authority

### Database Migration
Run the `border_official_assignments.sql` migration to:
- Create the border_assignments table
- Add necessary indexes and RLS policies
- Create management functions
- Set up proper permissions

## Benefits

1. **Enhanced Security**: Granular control over which borders each official can access
2. **Audit Trail**: Complete tracking of border assignments and changes
3. **Flexibility**: Officials can be assigned to multiple borders as needed
4. **Scalability**: System supports large numbers of borders and officials
5. **Compliance**: Meets requirements for controlled border access management

## Future Enhancements

- **Time-based Assignments**: Add support for temporary assignments with expiration dates
- **Shift Management**: Integration with duty roster systems
- **Automated Assignments**: Rules-based assignment based on location or specialization
- **Mobile Notifications**: Alert officials when they receive new border assignments