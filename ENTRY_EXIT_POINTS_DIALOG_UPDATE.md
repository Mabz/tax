# Entry/Exit Points Dialog Implementation

## Changes Made

### 1. PassSelectionDialog Updates

**Added State Variables:**
- `_userSelectedEntryPoint` - Stores user-selected entry point
- `_userSelectedExitPoint` - Stores user-selected exit point  
- `_availableBorders` - List of available borders for selection
- `_isLoadingBorders` - Loading state for border data

**Added Methods:**
- `_loadBordersForTemplate()` - Loads borders when template allows user selection
- `_selectTemplate()` - Handles template selection and triggers border loading
- `_canSelectTemplate()` - Validates that entry/exit points are selected when required

**Updated Template Display:**
- When `allowUserSelectablePoints = false`: Shows fixed entry/exit points as text
- When `allowUserSelectablePoints = true` AND template is selected:
  - Shows loading indicator while borders load
  - Shows entry point dropdown (required, no null option)
  - Shows exit point dropdown (required, no null option)
  - Dropdowns only appear for the selected template

**Updated Select Button:**
- Only enabled when template is selected AND (if user-selectable) both entry/exit points are chosen
- Returns a Map containing template and selected entry/exit points instead of just the template

### 2. Main Pass Dashboard Updates

**Updated Dialog Handling:**
- `_showPassSelectionDialog()` now expects Map return type instead of PassTemplate
- Extracts template and user-selected points from dialog result
- Stores user selections in existing state variables

**Updated Pass Details Display:**
- For user-selectable templates: Shows selected entry/exit point names
- For fixed templates: Shows template's predefined entry/exit points
- Removed the old dropdown selection UI from main screen (now handled in dialog)

**Updated Purchase Flow:**
- Validation ensures entry/exit points are selected when required
- Purchase method passes user-selected points to the service

## User Experience Flow

### For Templates with Fixed Entry/Exit Points (allowUserSelectablePoints = false)
1. User sees template with fixed entry/exit points displayed as text
2. User can select template immediately
3. Select button is enabled as soon as template is chosen
4. Purchase proceeds with template's predefined points

### For Templates with User-Selectable Points (allowUserSelectablePoints = true)
1. User sees template with authority name and other details
2. When user clicks on template:
   - Template becomes selected
   - Loading indicator appears
   - Borders are loaded from the database
3. Entry and exit point dropdowns appear (no "Any" or null options)
4. User must select both entry and exit points
5. Select button only becomes enabled after both selections are made
6. Purchase proceeds with user-selected points

## Key Features

✅ **Conditional UI**: Entry/exit dropdowns only show for selected templates that allow user selection
✅ **Required Selection**: Both entry and exit points must be selected (no null options)
✅ **Loading States**: Shows loading indicator while borders are being fetched
✅ **Validation**: Select button disabled until all required selections are made
✅ **Clean UX**: Selection happens in dialog, main screen shows final selections
✅ **Backward Compatibility**: Fixed templates continue to work as before

## Database Requirements

The "Unknown Authority" error still needs to be fixed by running:
```sql
-- Execute supabase_fix_authority_name.sql
```

This will add the missing `authority_name` field to the `get_pass_templates_for_authority` function.

## Testing Checklist

- [ ] Templates with fixed points show entry/exit as text, Select button works immediately
- [ ] Templates with user-selectable points show dropdowns only when selected
- [ ] Entry/exit dropdowns have no null/"Any" options
- [ ] Select button disabled until both entry and exit are chosen
- [ ] Selected entry/exit points display correctly in main screen
- [ ] Purchase works with user-selected points
- [ ] Authority names show correctly after database fix