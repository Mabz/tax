# GPS Validation and Border Selection System Implementation

## Overview
This implementation addresses the critical issue of border officials assigned to multiple borders by adding GPS validation and proper border selection with comprehensive audit logging.

## Key Features Implemented

### 1. **GPS Distance Validation**
- **30km Rule**: Validates if current GPS is within 30km of selected border
- **Configurable Distance**: Can be adjusted per border or globally
- **Haversine Formula**: Accurate distance calculation between GPS coordinates
- **Comprehensive Logging**: All validations logged in `pass_processing_audit` table

### 2. **Border Selection System**
- **Multi-Border Support**: Shows all borders assigned to an official
- **Nearest Border Default**: Auto-selects closest border based on GPS
- **Permission Display**: Shows check-in/check-out permissions per border
- **Distance Display**: Shows distance to each border

### 3. **Violation Handling**
- **Warning Dialog**: Shows exact distance when outside 30km range
- **Official Decision Logging**: Records whether official proceeds or cancels
- **Override Capability**: Allows processing with logged justification
- **Audit Trail**: Complete record of all decisions and overrides

## Database Components

### New SQL Functions Created

1. **`calculate_distance_km(lat1, lon1, lat2, lon2)`**
   - Calculates distance using Haversine formula
   - Returns distance in kilometers
   - Handles null coordinates gracefully

2. **`get_official_assigned_borders(profile_id)`**
   - Returns all borders assigned to an official
   - Includes permissions and coordinates
   - Ordered by border name

3. **`validate_border_gps_distance(pass_id, border_id, lat, lon, max_km)`**
   - Validates GPS distance to border
   - Logs validation result in audit table
   - Returns detailed validation information

4. **`log_distance_violation_response(audit_id, decision, notes)`**
   - Logs official's decision on distance violations
   - Updates original audit record
   - Creates new audit entry for the decision

5. **`find_nearest_assigned_border(profile_id, lat, lon)`**
   - Finds nearest borders from official's assignments
   - Returns top 10 sorted by distance
   - Includes distance calculations

6. **`process_pass_movement_with_gps_validation(...)`**
   - Enhanced processing with GPS validation
   - Supports validation override with logging
   - Comprehensive audit logging

## Application Components

### 1. **BorderSelectionService**
- Handles all border selection and GPS validation logic
- Provides clean API for UI components
- Manages communication with database functions

### 2. **BorderSelectionWidget**
- Dropdown for selecting from assigned borders
- Shows distance and permissions for each border
- Auto-selects nearest border
- Displays warnings for distant borders

### 3. **GpsValidationDialog**
- Shows GPS violation warnings
- Displays exact distance and border details
- Allows official to proceed or cancel
- Logs the decision automatically

## Implementation Scenarios

### Scenario 1: Pass HAS entry_point_id or exit_point_id
```dart
// 1. Get the specific border from pass
String borderId = pass.entryPointId ?? pass.exitPointId;

// 2. Validate GPS distance
GpsValidationResult validation = await BorderSelectionService.validateBorderGpsDistance(
  passId: pass.id,
  borderId: borderId,
  currentLat: position.latitude,
  currentLon: position.longitude,
);

// 3. If outside range, show warning dialog
if (!validation.withinRange) {
  // Show GpsValidationDialog
  // Log official's decision
  // Proceed with override if approved
}
```

### Scenario 2: Pass has NO entry_point_id or exit_point_id
```dart
// 1. Show BorderSelectionWidget
// 2. Official selects from assigned borders
// 3. Still validate GPS distance to selected border
// 4. Same violation handling as Scenario 1
```

## Audit Logging

All actions are logged in `pass_processing_audit` table:

### GPS Validation Events
- `gps_validation_passed` - Within acceptable range
- `gps_validation_failed` - Outside acceptable range
- `gps_validation_override` - Official chose to proceed anyway

### Official Decision Events
- `distance_violation_proceed` - Official chose to continue
- `distance_violation_cancel` - Official chose to cancel

### Processing Events
- `check_in_completed` - Successful check-in with GPS data
- `check_out_completed` - Successful check-out with GPS data

## Configuration

### Distance Threshold
```sql
-- Default 30km, but configurable per call
SELECT validate_border_gps_distance(
  pass_id, border_id, lat, lon, 
  50 -- Custom distance in km
);
```

### Metadata Logged
```json
{
  "validation_type": "gps_distance_check",
  "border_coordinates": {"latitude": -26.3054, "longitude": 31.1367},
  "current_coordinates": {"latitude": -26.2054, "longitude": 31.2367},
  "distance_km": 12.5,
  "max_allowed_km": 30,
  "within_range": true,
  "official_decision": "proceed",
  "decision_notes": "Emergency processing required"
}
```

## Integration Points

### Authority Validation Screen
```dart
// Replace existing border selection logic
if (widget.role == AuthorityRole.borderOfficial) {
  // Show BorderSelectionWidget if multiple borders
  // Use BorderSelectionService for processing
  // Handle GPS validation results
}
```

### Enhanced Border Service
```dart
// Update processPassMovement to use new validation
static Future<BorderProcessingResult> processPassMovement({
  required String passId,
  required String borderId,
  // ... existing parameters
}) async {
  return BorderSelectionService.processPassMovementWithGpsValidation(
    // ... parameters with GPS validation
  );
}
```

## Benefits

1. **Data Integrity**: Ensures movements are recorded at correct borders
2. **Audit Compliance**: Complete trail of all decisions and overrides
3. **Flexibility**: Supports emergency/mobile processing scenarios
4. **User Experience**: Clear warnings and easy border selection
5. **Security**: Prevents accidental processing at wrong borders

## Next Steps

1. **Apply SQL Functions**: Run the SQL files to create database functions
2. **Update Authority Validation Screen**: Integrate BorderSelectionWidget
3. **Test GPS Validation**: Verify distance calculations and logging
4. **Configure Distance Thresholds**: Adjust 30km rule if needed
5. **Train Officials**: Educate on new border selection process

## Files Created

1. `create_gps_validation_system.sql` - Core GPS validation functions
2. `create_enhanced_border_processing.sql` - Enhanced processing with validation
3. `lib/services/border_selection_service.dart` - Service layer
4. `lib/widgets/border_selection_widget.dart` - UI components

This implementation ensures that border officials with multiple assignments can properly select their current border while maintaining strict GPS validation and comprehensive audit logging.