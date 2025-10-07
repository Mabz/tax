# Local Authority Movement History UI Improvements

## Changes Made

### 1. Removed Entry/Exit Labels for Local Authority Scans
- Added conditional logic to only show the blue/green "ENTRY"/"EXIT" labels for border movements
- Local authority movements no longer display these labels as they don't represent border crossings

### 2. Removed Status Change Information
- Status change details (`previous_status → new_status`) are now only shown for border movements
- Local authority scans don't change pass status, so this information is not relevant

### 3. Removed "Border: Local Authority" Label
- Changed the label from "Border" to "Local Authority" for local authority movements
- This better reflects that these are local authority scans, not border crossings

### 4. Updated Official Label
- For border movements: Shows "Official: [Official Name]"
- For local authority movements: Shows "Local Authority: [Authority Name]" (using the borderName field which contains the local authority name)

### 5. Added Visual Distinction
- Local authority movements now use an orange security icon instead of login/logout icons
- This helps users quickly distinguish between border crossings and local authority scans

## Implementation Details

### Helper Method Added
```dart
bool _isLocalAuthorityMovement(PassMovement movement) {
  return movement.movementType == 'local_authority_scan' ||
         movement.authorityType == 'local_authority' ||
         movement.scanPurpose != null;
}
```

### Conditional Display Logic
- Entry/Exit labels: Only shown for non-local authority movements
- Status change: Only shown for border movements
- Authority information: Shows "Local Authority" instead of "Official" for local authority scans
- Icons: Uses security icon (orange) for local authority, login/logout icons for border movements

## Result
Local authority movement history entries now display:
- ✅ Clean title (Routine Check, Roadblock, etc.)
- ✅ Local Authority name instead of "Official"
- ✅ Processing timestamp
- ✅ Location coordinates
- ✅ Entries deducted (if applicable)
- ❌ No Entry/Exit labels
- ❌ No Status Change information
- ❌ No "Border:" prefix

Border movement history entries continue to show all original information including Entry/Exit labels and status changes.