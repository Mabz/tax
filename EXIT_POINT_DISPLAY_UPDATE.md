# Exit Point Display Update

## Overview
Updated the pass selection interface to consistently show Exit Point information alongside Entry Point information for all pass templates (unless user-selectable points are enabled).

## Changes Made

### 1. Pass Selection Dialog
**Location:** PassSelectionDialog in pass_dashboard_screen.dart

**Before:** Only showed Exit Point if `template.exitPointName != null`
```dart
if (template.exitPointName != null)
  Text('Exit Point: ${template.exitPointName}')
```

**After:** Always shows Exit Point with fallback text
```dart
Text('Exit Point: ${template.exitPointName ?? 'Any Exit Point'}')
```

### 2. Pass Details Section
**Location:** Pass template details after selection

**Before:** Conditionally showed Exit Point only if not null
```dart
if (_selectedPassTemplate!.exitPointName != null)
  _buildDetailRow('Exit Point', _selectedPassTemplate!.exitPointName!)
```

**After:** Always shows Exit Point with fallback
```dart
_buildDetailRow('Exit Point', 
    _selectedPassTemplate!.exitPointName ?? 'Any Exit Point')
```

### 3. Purchase Summary Section
**Location:** Final purchase summary before payment

**Before:** Conditionally showed Exit Point
```dart
if (_selectedPassTemplate?.exitPointName != null)
  _buildSummaryRow('Exit Point', _selectedPassTemplate!.exitPointName!)
```

**After:** Always shows Exit Point with fallback
```dart
_buildSummaryRow('Exit Point',
    _selectedPassTemplate?.exitPointName ?? 'Any Exit Point')
```

## User Experience Improvements

### Consistent Information Display
- **Entry Point:** Always displayed with fallback "Any Entry Point"
- **Exit Point:** Always displayed with fallback "Any Exit Point"
- **User-Selectable Points:** Shows selection dropdowns when enabled

### Clear Visual Hierarchy
- Both entry and exit points are shown at the same level
- Consistent formatting and styling
- Clear fallback text when specific points aren't defined

### Complete Information
- Users can see both entry and exit point information before purchasing
- No hidden or conditional information that might surprise users
- Consistent experience across all pass templates

## Technical Implementation

### Fallback Values
- **"Any Entry Point"** - when `entryPointName` is null
- **"Any Exit Point"** - when `exitPointName` is null
- Maintains consistency with existing entry point fallback logic

### Conditional Logic
- **User-selectable points:** Shows selection dropdowns for both entry and exit
- **Fixed points:** Shows template-defined points with fallbacks
- **Mixed scenarios:** Handles cases where only one point is defined

### Display Locations Updated
1. **Pass Selection Dialog** - Template list with entry/exit info
2. **Pass Details Section** - Detailed view after template selection  
3. **Purchase Summary** - Final confirmation before payment

## Benefits

### For Users
- **Complete Information:** See both entry and exit points upfront
- **No Surprises:** Consistent information display
- **Better Decision Making:** Full context for pass selection

### For System
- **Consistent UI:** Same information shown everywhere
- **Reduced Confusion:** Clear fallback values
- **Better UX:** No missing or conditional information

## Testing Scenarios

- [ ] Pass templates with both entry and exit points defined
- [ ] Pass templates with only entry point defined
- [ ] Pass templates with only exit point defined  
- [ ] Pass templates with neither point defined
- [ ] User-selectable point templates
- [ ] Mixed scenarios across different authorities

## Future Considerations

### Potential Enhancements
- **Icons:** Add entry/exit icons for better visual distinction
- **Validation:** Ensure entry and exit points are different when both specified
- **Routing:** Show route information between entry and exit points
- **Costs:** Display different costs for different entry/exit combinations

### Database Considerations
- Ensure exit point data is properly populated in pass templates
- Consider making exit points mandatory for certain pass types
- Add validation rules for entry/exit point combinations