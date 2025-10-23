# Audit Display Corrections

## Issues Corrected

### 1. **Notes Position**
**Problem:** Notes were displayed on a separate line, taking up too much vertical space
**Solution:** Moved notes to display inline next to the time

**Before:**
```
⏰ 8m ago
📝 Checking stuff out
```

**After:**
```
⏰ 8m ago 📝 Checking stuff out
```

### 2. **Status Display Format**
**Problem:** Entry deductions showed as just numbers (e.g., "1 entry")
**Solution:** Changed to clear format "Entries Deducted: X"

**Before:**
```
[-1 entry]
```

**After:**
```
[Entries Deducted: 1]
```

### 3. **Scan Purpose Already Working**
**Confirmed:** The title already correctly shows formatted scan purposes:
- `roadblock` → **"Roadblock"**
- `routine_check` → **"Routine Check"**
- `security_inspection` → **"Security Inspection"**

## Implementation Details

### Inline Notes Display
```dart
Row(
  children: [
    Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
    const SizedBox(width: 4),
    Text(_formatDateTime(movement.processedAt)),
    if (movement.notes != null && movement.notes!.isNotEmpty) ...[
      const SizedBox(width: 12),
      Icon(Icons.note, size: 12, color: Colors.grey.shade600),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          movement.notes!,
          style: TextStyle(fontStyle: FontStyle.italic),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ],
)
```

### Clear Entry Deduction Format with Color Coding
```dart
Widget _buildMovementTrailing(PassMovement movement) {
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

## Real-World Example

Based on the provided data:
```json
{
  "movement_type": "local_authority_scan",
  "entries_deducted": 0,
  "notes": "Checking stuff out",
  "scan_purpose": "roadblock"
}
```

**Display Result (entries_deducted: 0):**
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago 📝 Checking stuff out
                    [Entries Deducted: 0] (Green)
```

**If entries were deducted (entries_deducted: 1):**
```
🚔 Roadblock
Bobby • Local Authority
⏰ 8m ago 📝 Checking stuff out
                    [Entries Deducted: 1] (Red)
```

## Benefits

1. **Space Efficiency**: Notes inline with time saves vertical space
2. **Clarity**: "Entries Deducted: X" with color coding (Green=0, Red>0)
3. **Consistency**: All information flows naturally in the layout
4. **Readability**: Single line format is easier to scan quickly