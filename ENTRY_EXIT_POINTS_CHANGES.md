# Entry/Exit Points Implementation Summary

## Changes Made

### 1. PassTemplate Model Updates
- Renamed `borderId` to `entryPointId`
- Added `exitPointId` field
- Renamed `borderName` to `entryPointName`
- Added `exitPointName` field
- Added `allowUserSelectablePoints` boolean field
- Updated constructors, fromJson, toJson, and copyWith methods

### 2. PurchasedPass Model Updates
- Renamed `borderName` to `entryPointName`
- Added `exitPointName` field
- Renamed `borderId` to `entryPointId`
- Added `exitPointId` field
- Updated all related methods to support both legacy and new field names

### 3. PassTemplateService Updates
- Updated `createPassTemplate` method to accept `entryPointId`, `exitPointId`, and `allowUserSelectablePoints`
- Updated `updatePassTemplate` method with same new parameters
- Modified response parsing to handle both legacy `border_name` and new `entry_point_name` fields

### 4. Pass Template Management Screen Updates
- Replaced single "Border" dropdown with separate "Entry Point" and "Exit Point" dropdowns
- Added checkbox for "Allow users to select entry/exit points"
- Updated state variables: `_selectedBorder` → `_selectedEntryPoint`, added `_selectedExitPoint`
- Added `_allowUserSelectablePoints` boolean state
- Updated description generation to show route information
- Updated confirmation dialog to display entry/exit points separately
- Updated template list display to show both entry and exit points

### 5. Key Features Implemented
- **Flexible Entry/Exit Selection**: Authorities can now specify different entry and exit points for passes
- **User-Selectable Points**: Checkbox allows users to choose their own entry/exit points during purchase
- **Backward Compatibility**: All changes support legacy `border_id`/`border_name` fields
- **Enhanced Descriptions**: Auto-generated descriptions now show route information (from X to Y)

### 6. Database Schema Requirements
The following database changes will be needed:
- Add `entry_point_id` column to `pass_templates` table
- Add `exit_point_id` column to `pass_templates` table  
- Add `allow_user_selectable_points` boolean column to `pass_templates` table
- Update stored procedures/functions to handle new fields
- Add similar fields to `purchased_passes` table for storing user selections

### 7. Next Steps for Purchase Flow
When implementing the purchase flow, you'll need to:
- Check if `allowUserSelectablePoints` is true for the template
- If true, show entry/exit point selection dropdowns to the user
- Store the selected entry/exit point IDs in the purchased pass record
- Validate that selected points are valid for the authority

This implementation provides a flexible foundation for border crossing passes while maintaining backward compatibility with existing data.