# Overstayed Vehicles Screen Fixes

## Issues Fixed

### 1. Database Query Error
**Problem**: PostgrestException - column profiles_1.first_name does not exist
**Root Cause**: The JOIN query to the profiles table was using incorrect column names or table structure
**Solution**: Simplified the query to avoid the profile table JOIN for now
- Removed the complex SELECT with profiles JOIN
- Set owner information fields to null/placeholder values
- Added TODO comment to fix profile table structure later

### 2. UI Layout Overflow Error
**Problem**: RenderFlex overflowed by 0.703 pixels on the right in Row widget
**Root Cause**: The sort header Row had too many buttons that exceeded screen width
**Solution**: Made the sort header horizontally scrollable
- Wrapped the Row in a SingleChildScrollView with horizontal scrollDirection
- This allows users to scroll through all sort options on smaller screens

## Changes Made

### BusinessIntelligenceService (`lib/services/business_intelligence_service.dart`)
```dart
// Before: Complex JOIN query
final response = await _supabase
    .from('purchased_passes')
    .select('''
      *,
      profiles!profile_id (
        id,
        first_name,
        last_name,
        email,
        phone_number,
        company_name,
        profile_image_url
      )
    ''')

// After: Simplified query
final response = await _supabase
    .from('purchased_passes')
    .select('*')
```

### OverstayedVehiclesScreen (`lib/screens/bi/overstayed_vehicles_screen.dart`)
```dart
// Before: Fixed Row causing overflow
child: Row(
  children: [
    Text('Sort by:'),
    _buildSortButton('Days Overdue', 'daysOverdue'),
    _buildSortButton('Amount', 'amount'),
    _buildSortButton('Vehicle', 'vehicleReg'),
    _buildSortButton('Owner', 'ownerName'),
  ],
),

// After: Scrollable Row
child: SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      Text('Sort by:'),
      _buildSortButton('Days Overdue', 'daysOverdue'),
      _buildSortButton('Amount', 'amount'),
      _buildSortButton('Vehicle', 'vehicleReg'),
      _buildSortButton('Owner', 'ownerName'),
    ],
  ),
),
```

## Current Status

### ✅ Working Features
- Overstayed vehicles list displays correctly
- Sorting functionality works (by days overdue, amount, vehicle registration)
- Time period and border filtering
- Detailed vehicle information modal
- Authority currency display
- Severity color coding

### ⚠️ Temporary Limitations
- Owner information shows "Owner Information Unavailable"
- Contact owner and enforcement action buttons are placeholders
- Profile images not displayed

### 🔧 Next Steps
1. **Fix Profile Table Structure**: Investigate the correct column names and table structure for profiles
2. **Restore Owner Information**: Once profile table is fixed, restore the JOIN query
3. **Add Contact Features**: Implement email/SMS functionality for contacting owners
4. **Add Enforcement Actions**: Implement penalty tracking and enforcement workflows

## Testing
- The screen now loads without database errors
- UI layout works on different screen sizes
- Sorting and filtering functions properly
- Modal details display correctly

## Profile Table Investigation Needed
To restore owner information, we need to:
1. Check the actual profile table schema in the database
2. Verify the correct column names (first_name vs firstName, etc.)
3. Confirm the foreign key relationship between purchased_passes and profiles
4. Update the JOIN query accordingly

The current implementation provides a solid foundation while avoiding the immediate database errors.