# Vehicle Details Addition to Audit Trail

## Enhancement Overview
Added brief vehicle information display to the audit trail to help border officials quickly identify which vehicle was involved in each activity.

## Implementation Details

### Database Query Enhancement
Added vehicle fields to the database query:
```sql
SELECT 
  id,
  pass_id,
  movement_type,
  entries_deducted,
  ...
  purchased_passes!inner(
    id,
    vehicle_description,
    vehicle_registration_number,  -- ✅ ADDED
    vehicle_make,                 -- ✅ ADDED
    vehicle_model,                -- ✅ ADDED
    status,
    ...
  )
```

### PassMovement Class Enhancement
Added vehicle fields to the PassMovement class:
```dart
class PassMovement {
  // ... existing fields
  final String? vehicleDescription;
  final String? vehicleRegistration;
  final String? vehicleMake;
  final String? vehicleModel;
}
```

### Display Logic
```dart
String _formatVehicleInfo(PassMovement movement) {
  final parts = <String>[];
  
  // Priority: Registration number first
  if (movement.vehicleRegistration != null && movement.vehicleRegistration!.isNotEmpty) {
    parts.add(movement.vehicleRegistration!);
  }
  
  // Then: Make and Model combined
  if (movement.vehicleMake != null && movement.vehicleMake!.isNotEmpty) {
    if (movement.vehicleModel != null && movement.vehicleModel!.isNotEmpty) {
      parts.add('${movement.vehicleMake} ${movement.vehicleModel}');
    } else {
      parts.add(movement.vehicleMake!);
    }
  }
  
  // Fallback: Vehicle description if nothing else available
  if (parts.isEmpty && movement.vehicleDescription != null) {
    parts.add(movement.vehicleDescription!);
  }
  
  return parts.join(' • ');
}
```

## Visual Examples

### Complete Vehicle Information
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago 📝 Checking stuff out
🚗 ABC123GP • Toyota Corolla
🎫 Pass: 3d86210f...
                    [Entries Deducted: 0] (Green)
```

### Registration Only
```
🔍 Vehicle Check-In
Bobby • Ngwenya Border
⏰ Yesterday, 4:30 PM
🚗 XYZ789GP
🎫 Pass: 7f42a8b9...
                    [Entries Deducted: 1] (Red)
```

### Make/Model Only
```
🚔 Security Check
Bobby • Local Authority
⏰ Yesterday, 3:15 PM 📝 Thorough inspection
🚗 Honda Civic
                    [Entries Deducted: 1] (Red)
```

### No Vehicle Information
```
🔄 System Update
System • Local Authority
⏰ Yesterday, 1:00 PM
                    [Entries Deducted: 0] (Green)
```

## Benefits

### **For Border Officials:**
1. **Quick Vehicle Identification**: Instantly see which vehicle was involved
2. **Pattern Recognition**: Identify repeat vehicles or suspicious patterns
3. **Context Enhancement**: Better understanding of each activity
4. **Investigation Support**: Vehicle details aid in incident tracking

### **For Audit Purposes:**
1. **Complete Records**: Vehicle information included in audit trail
2. **Traceability**: Link activities to specific vehicles
3. **Compliance**: Better documentation for regulatory requirements
4. **Evidence**: Vehicle details support legal proceedings

## Technical Features

### **Smart Display Logic:**
- Prioritizes registration number (most important identifier)
- Combines make and model intelligently
- Falls back to vehicle description if needed
- Only shows vehicle info when available

### **Space Efficient:**
- Single line display with car icon
- Truncates long text with ellipsis
- Maintains clean layout

### **Data Integrity:**
- Handles null/empty values gracefully
- No errors when vehicle data is missing
- Backward compatible with existing data

## Real-World Use Cases

### **Border Checkpoint Scenario:**
```
🔍 Vehicle Check-In
Bobby • Ngwenya Border
⏰ 2h ago
🚗 SZ123ABC • Toyota Hilux
                    [Entries Deducted: 1] (Red)
```

### **Local Authority Roadblock:**
```
🚔 Roadblock
Bobby • Local Authority
⏰ 30m ago 📝 Routine traffic stop
🚗 GP456DEF • BMW X3
                    [Entries Deducted: 0] (Green)
```

### **Security Inspection:**
```
🚔 Security Check
Bobby • Local Authority
⏰ 1h ago 📝 Suspicious behavior reported
🚗 MP789GHI • Ford Ranger
                    [Entries Deducted: 1] (Red)
```

This enhancement provides border officials with immediate vehicle context for each audit trail entry, making the system more informative and useful for tracking and investigation purposes.