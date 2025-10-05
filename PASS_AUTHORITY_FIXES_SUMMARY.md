# Pass Authority and User-Selectable Points Fixes

## Issues Fixed

### 1. Unknown Authority in Pass Template Selection
**Problem:** Pass templates were showing "Unknown Authority" when users were selecting passes to purchase.

**Root Cause:** The `getPassTemplatesForAuthority` method was using an RPC function that didn't include authority name information.

**Solution:**
- Updated `PassService.getPassTemplatesForAuthority()` to use direct database queries with proper joins
- Added authority, country, vehicle type, and border information joins
- Added fallback logic for when direct queries fail
- Enhanced error handling and debugging

**Files Modified:**
- `lib/services/pass_service.dart`

### 2. User-Selectable Points Not Working Properly
**Problem:** When creating pass templates with `allow_user_selectable_points = true`, the system was still showing and storing fixed entry/exit points instead of forcing user selection during purchase.

**Root Cause:** 
- Template creation logic wasn't setting entry/exit points to null when user-selectable was enabled
- Display logic was still showing fixed points even for user-selectable templates
- Checkbox logic was setting a default entry point instead of clearing it

**Solution:**
- Fixed checkbox logic to clear entry/exit points when user-selectable is enabled
- Updated template creation/update logic to explicitly set entry/exit point IDs to null when `allowUserSelectablePoints` is true
- Updated display logic to hide entry/exit point information for user-selectable templates
- Updated description generation to show "User selectable" for these templates

**Files Modified:**
- `lib/screens/pass_template_management_screen.dart`
- `lib/services/pass_service.dart` (template fetching logic)

## Database Fixes

### SQL Scripts Created:
1. `fix_pass_authorities.sql` - Fixes existing passes with missing authority information
2. `fix_user_selectable_templates.sql` - Fixes existing templates with user-selectable points
3. `fix_pass_authorities.dart` - Dart script for fixing pass authority data

## Key Changes Made

### PassService Updates:
- Enhanced `getPassTemplatesForAuthority()` with proper joins
- Added authority name fetching for pass templates
- Improved error handling and fallback mechanisms
- Added logic to hide entry/exit point names for user-selectable templates

### Pass Template Management Updates:
- Fixed user-selectable points checkbox logic
- Updated template creation/update to properly handle null entry/exit points
- Enhanced display logic to show appropriate information based on template type
- Improved description generation for user-selectable templates

### Pass Card Widget Updates:
- Added authority and country information display
- Enhanced pass details section with proper authority information

## Testing Recommendations

1. **Test Pass Template Selection:**
   - Verify that pass templates now show proper authority names instead of "Unknown Authority"
   - Check that templates with user-selectable points show "User selectable" instead of fixed points

2. **Test Template Creation:**
   - Create a new template with `allow_user_selectable_points = true`
   - Verify that entry/exit point dropdowns are hidden
   - Confirm that the template is saved with null entry/exit point IDs

3. **Test Pass Purchase Flow:**
   - Select a template with user-selectable points
   - Verify that the user is forced to select entry/exit points during purchase
   - Confirm that templates with fixed points don't show selection options

4. **Test Database Fixes:**
   - Run the SQL scripts to fix existing data
   - Verify that existing passes now show proper authority information
   - Confirm that user-selectable templates have null entry/exit point IDs

## Deployment Steps

1. Deploy the code changes
2. Run the SQL fix scripts in the database:
   ```sql
   -- Fix existing pass authority data
   \i fix_pass_authorities.sql
   
   -- Fix existing user-selectable templates
   \i fix_user_selectable_templates.sql
   ```
3. Test the application to verify fixes are working
4. Monitor for any remaining "Unknown Authority" issues

## Future Improvements

1. Consider adding validation to prevent templates with user-selectable points from having fixed entry/exit points
2. Add database constraints to enforce the relationship between `allow_user_selectable_points` and null entry/exit point IDs
3. Consider adding a migration to automatically fix any future data inconsistencies