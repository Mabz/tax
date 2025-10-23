# Entries Deducted Color Coding Implementation

## Requirement
Always display "Entries Deducted: X" with color coding based on the `entries_deducted` column value:
- **Green** when `entries_deducted = 0` (no impact on pass)
- **Red** when `entries_deducted > 0` (pass entries consumed)

## Implementation

### Color Logic
```dart
Widget _buildMovementTrailing(PassMovement movement) {
  // Always show entries deducted with color coding
  // Green for 0 entries deducted, Red for > 0 entries deducted
  final isDeducted = movement.entriesDeducted > 0;
  final backgroundColor = isDeducted ? Colors.red.shade100 : Colors.green.shade100;
  final textColor = isDeducted ? Colors.red.shade700 : Colors.green.shade700;
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'Entries Deducted: ${movement.entriesDeducted}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
  );
}
```

## Visual Examples

### No Entry Deduction (entries_deducted: 0)
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago 📝 Checking stuff out
                    [Entries Deducted: 0] 🟢
```

### Entry Deducted (entries_deducted: 1)
```
🔍 Vehicle Check-In
Bobby • Ngwenya Border
⏰ Yesterday, 4:30 PM
                    [Entries Deducted: 1] 🔴
```

### Multiple Entries Deducted (entries_deducted: 2)
```
🚔 Security Check
Bobby • Local Authority
⏰ Yesterday, 3:15 PM 📝 Thorough inspection required
                    [Entries Deducted: 2] 🔴
```

## Benefits

### **For Border Officials:**
1. **Immediate Visual Feedback**: Green/red color coding provides instant understanding
2. **Impact Assessment**: Quickly see which activities consumed pass entries
3. **Pattern Recognition**: Identify high-impact vs. low-impact activities
4. **Audit Clarity**: Clear distinction between informational scans and entry-consuming activities

### **For System Understanding:**
1. **Consistent Display**: Always shows the same format regardless of value
2. **Data Accuracy**: Directly reflects the database `entries_deducted` column
3. **Visual Hierarchy**: Color coding helps prioritize information
4. **User Experience**: Intuitive green=good, red=impact color scheme

## Real-World Scenarios

### Informational Scans (Green)
- System status updates
- Informational checks that don't consume entries
- Administrative activities
- Verification scans that don't impact pass balance

### Entry-Consuming Activities (Red)
- Border crossings
- Security inspections that consume entries
- Roadblock checks with entry deduction
- Any activity that reduces available pass entries

## Technical Notes

- Always reads from `movement.entriesDeducted` column
- No conditional logic - always displays the format
- Color coding is automatic based on value
- Maintains consistent styling across all audit dialogs
- Responsive design works on all screen sizes