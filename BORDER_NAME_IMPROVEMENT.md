# Border Name Display Improvement

## Problem Identified
When local authority scans are performed, the system sometimes shows "Unknown Border" instead of a meaningful location name, which can be confusing for border officials reviewing audit trails.

## Solution Implemented
Added intelligent border name formatting that detects when:
- Border name is "Unknown Border" 
- Movement type is "local_authority_scan"

In these cases, the display automatically shows "Local Authority" instead of "Unknown Border".

## Before vs After

### ❌ Before
```
🚔 Routine Check
Bobby • Unknown Border
Yesterday, 5:02 PM
```

### ✅ After  
```
🚔 Routine Check
Bobby • Local Authority
Yesterday, 5:02 PM
```

## Implementation Details

### New Helper Method
```dart
String _formatBorderName(String borderName, String movementType) {
  // If it's "Unknown Border" and it's a local authority scan, show "Local Authority"
  if (borderName.toLowerCase() == 'unknown border' && 
      movementType.toLowerCase() == 'local_authority_scan') {
    return 'Local Authority';
  }
  return borderName;
}
```

### Updated Locations
The improvement applies to all places where border names are displayed:
1. **Official Information Section** - Shows "Local Authority" in official details
2. **Location Information Section** - Shows "Local Authority" in border/checkpoint field
3. **Map Preview** - Shows "Local Authority" in location label
4. **Pass Movement History** - Shows "Local Authority" in movement list

## Benefits

1. **Clarity**: Officials immediately understand this was a local authority activity
2. **Consistency**: Aligns with the scan purpose formatting (e.g., "Routine Check")
3. **Context**: Provides meaningful location context instead of "Unknown"
4. **User Experience**: Reduces confusion when reviewing audit trails

## Technical Notes

- Only affects display formatting, doesn't change underlying data
- Maintains backward compatibility with existing data
- Applied consistently across both audit dialogs
- Case-insensitive matching for robustness