# Vehicle Type Display Fix

## Issues Fixed

### 1. Vehicle Type Not Showing in Purchase Summary
**Problem:** Vehicle Type was showing as empty in the Purchase Summary section.

**Root Cause:** The pass template query was not fetching vehicle type names due to the simplified query structure implemented to avoid complex join issues.

**Solution:**
- Added separate vehicle type name fetching after the main pass template query
- Fetches all vehicle type names in a single query for efficiency
- Added vehicle type name mapping to both main query and RPC fallback
- Added fallback display text "Any Vehicle Type" when vehicle type is missing

### 2. Database Column Name Issue (Pending Investigation)
**Problem:** Error `column vehicles.vin_number does not exist`

**Root Cause:** Likely a mismatch between expected column name and actual database schema.

**Investigation Steps:**
- Created `check_vehicle_schema.sql` to inspect actual database schema
- Need to run this to identify the correct column name
- May be in RPC functions rather than direct queries

## Changes Made

### lib/services/pass_service.dart
- **Enhanced pass template fetching** to include vehicle type names
- **Batch vehicle type query** for efficiency (single query for all templates)
- **Added vehicle type mapping** to template data
- **Updated fallback RPC logic** to also fetch vehicle type names
- **Improved error handling** for vehicle type fetching

### lib/screens/pass_dashboard_screen.dart
- **Added fallback text** for missing vehicle types: "Any Vehicle Type"
- **Improved user experience** when vehicle type data is unavailable

## Technical Implementation

### Efficient Data Fetching
```dart
// Fetch all vehicle type names in one query
final vehicleTypeIds = response
    .where((template) => template['vehicle_type_id'] != null)
    .map((template) => template['vehicle_type_id'])
    .toSet()
    .toList();

Map<String, String> vehicleTypeNames = {};
if (vehicleTypeIds.isNotEmpty) {
  final vehicleTypesResponse = await _supabase
      .from('vehicle_types')
      .select('id, name')
      .inFilter('id', vehicleTypeIds);
  
  for (final vt in vehicleTypesResponse) {
    vehicleTypeNames[vt['id']] = vt['name'];
  }
}
```

### Data Mapping
```dart
// Add vehicle type name to template data
if (templateData['vehicle_type_id'] != null) {
  final vehicleTypeName = vehicleTypeNames[templateData['vehicle_type_id']];
  if (vehicleTypeName != null) {
    templateData['vehicle_type'] = vehicleTypeName;
  }
}
```

## Benefits

1. **Complete Information:** Purchase summary now shows vehicle type information
2. **Efficient Queries:** Single batch query for all vehicle types instead of individual queries
3. **Fallback Handling:** Graceful degradation when vehicle type data is unavailable
4. **Consistent Experience:** Both main query and RPC fallback provide vehicle type names
5. **Error Resilience:** System continues to work even if vehicle type fetching fails

## Testing Checklist

- [ ] Vehicle Type displays correctly in Purchase Summary
- [ ] Different vehicle types show appropriate names (Car, Truck, etc.)
- [ ] Fallback text "Any Vehicle Type" shows when data is missing
- [ ] Pass templates load successfully with vehicle type information
- [ ] RPC fallback also includes vehicle type names
- [ ] No performance degradation from additional queries

## Next Steps

1. **Run database schema check:**
   ```sql
   \i check_vehicle_schema.sql
   ```

2. **Identify VIN column issue** and fix any RPC functions using wrong column names

3. **Test vehicle type display** in the purchase flow

4. **Verify performance** of the enhanced queries

## Database Investigation Required

The `vehicles.vin_number` error needs investigation:
- Check actual column name in vehicles table
- Review RPC function definitions
- Update any functions using incorrect column names
- Ensure consistency between application and database schema