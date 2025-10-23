# Notes and Status Display Improvements

## Problem Identified
The audit trail was showing generic "active" status which doesn't provide meaningful information, and notes from the database weren't being displayed to provide additional context about activities.

## Solutions Implemented

### 1. **Notes Display Enhancement**
- Added notes display when the note column is populated
- Shows with note icon (📝) for visual clarity
- Displays in italic text style to distinguish from other information
- Truncates long notes with ellipsis for clean layout
- Maximum 2 lines to prevent layout issues

### 2. **Contextual Status Display**
- Replaced generic "active" status with meaningful information
- Shows entries deducted when > 0 (e.g., "1 entry", "2 entries")
- Falls back to status display when no entries were deducted
- Uses red badge with minus icon for entry deductions
- Maintains color coding for other statuses

## Before vs After

### ❌ Before
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago
                    [active]
```

### ✅ After
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago 📝 Checking stuff out
                    [Entries Deducted: 0] (Green)
```

**When entries are deducted:**
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago 📝 Checking stuff out
                    [Entries Deducted: 1] (Red)
```

## Implementation Details

### Notes Display
```dart
if (movement.notes != null && movement.notes!.isNotEmpty) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      Icon(Icons.note, size: 12, color: Colors.grey.shade600),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          movement.notes!,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
],
```

### Contextual Status
```dart
Widget _buildMovementTrailing(PassMovement movement) {
  // Show entries deducted if > 0, otherwise show status
  if (movement.entriesDeducted > 0) {
    return Container(
      // Red badge with entry count
    );
  } else {
    return Container(
      // Status badge with color coding
    );
  }
}
```

## Benefits

### **For Border Officials:**
1. **Additional Context**: Notes provide specific details about what was done
2. **Meaningful Status**: Entry deductions show actual impact instead of generic "active"
3. **Quick Scanning**: Visual icons help identify different types of information
4. **Complete Picture**: Both notes and entry impact visible at a glance

### **For Audit Purposes:**
1. **Detailed Records**: Notes capture specific reasons for activities
2. **Impact Tracking**: Clear indication of when entries were consumed
3. **Compliance**: Better documentation for regulatory requirements
4. **Investigation**: More context available for incident reviews

## Real-World Examples

### Security Check with Notes
```
🚔 Security Check
Bobby • Local Authority
⏰ Yesterday, 3:15 PM 📝 Suspicious behavior observed, vehicle searched
                    [Entries Deducted: 1]
```

### Routine Check with Notes
```
🚔 Roadblock
Bobby • Local Authority
⏰ Yesterday, 2:30 PM 📝 Random inspection as per protocol
                    [Entries Deducted: 1]
```

### Border Crossing (No Notes)
```
🔍 Vehicle Check-In
Bobby • Ngwenya Border
⏰ Yesterday, 1:45 PM
                    [Entries Deducted: 1]
```

### System Activity (No Entry Deduction)
```
🔄 Status Update
System • Local Authority
⏰ Yesterday, 1:00 PM
                    [active]
```

## Technical Notes

- Notes are only displayed when the database column is populated and not empty
- Entry deduction display takes priority over status when entries > 0
- Maintains backward compatibility with existing data
- Responsive design handles long notes gracefully
- Consistent styling across all audit dialogs