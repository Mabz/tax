# Out-of-Schedule Scanning Implementation

## Overview
This implementation adds the ability for border officials to scan passes outside their scheduled time slots, with proper controls and audit logging.

## Features Implemented

### 1. **Border Configuration** 🏢
- **File**: `lib/screens/border_management_screen.dart` (modified existing)
- **Purpose**: Added "Allow Out-of-Schedule Scans" checkbox to existing border editing dialog
- **UI**: Toggle switch in the border edit dialog, right after the "Active" toggle
- **Database**: Uses new `allow_out_of_schedule_scans` column in `borders` table

### 2. **Schedule Validation Service** 🕐
- **File**: `lib/services/schedule_validation_service.dart`
- **Purpose**: Validate if border officials can scan at current time
- **Features**:
  - Check current time against official's schedule
  - Validate border's out-of-schedule policy
  - Return detailed validation results
  - Support for multiple time slots per day
  - Handle overnight shifts correctly

### 3. **Schedule Confirmation Dialog** ⚠️
- **File**: `lib/widgets/schedule_confirmation_dialog.dart`
- **Purpose**: Show confirmation dialog for out-of-schedule scans
- **Features**:
  - Display current time and official's schedule
  - Show border name and policy
  - Clear audit notice
  - User-friendly schedule visualization

### 4. **Pass Scanning Integration** 📱
- **File**: `lib/screens/authority_validation_screen.dart` (modified)
- **Purpose**: Integrate schedule validation into existing scan flow
- **Placement**: After pass verification, before role-specific processing
- **Logic**:
  - Border Officials only (Local Authority unaffected)
  - Check schedule → Check border policy → Show dialog → Log audit

### 5. **Platform-Aware Scanner** 🔧
- **Files**: 
  - `lib/utils/platform_scanner.dart` - Conditional export wrapper
  - `lib/utils/mobile_scanner_impl.dart` - Mobile implementation
  - `lib/utils/web_scanner_impl.dart` - Web stub implementation
- **Purpose**: Resolve mobile_scanner compilation issues on web
- **Features**: Unified API, platform-specific implementations

## Database Changes

### Migration File: `database_migration_out_of_schedule_scans.sql`

```sql
-- Add column to borders table
ALTER TABLE borders 
ADD COLUMN allow_out_of_schedule_scans BOOLEAN DEFAULT false;

-- Add performance index
CREATE INDEX idx_borders_out_of_schedule_setting 
ON borders(id, allow_out_of_schedule_scans) 
WHERE allow_out_of_schedule_scans = true;
```

### Audit Logging
- **Table**: Uses existing `audit_logs` table
- **Action**: `'out_of_schedule_scan'`
- **Metadata**: Includes pass ID, border ID, schedule details, confirmation status

## Scanning Flow

### Current Implementation
```
1. QR Code Detected
   ↓
2. Pass Verification (PassVerificationService.verifyPass)
   ↓
3. 🆕 Schedule Validation (Border Officials Only)
   ├─ Within Schedule → Continue
   ├─ Outside + Border Allows → Show Confirmation Dialog
   │  ├─ User Confirms → Log Audit + Continue
   │  └─ User Cancels → Block Scan
   └─ Outside + Border Blocks → Block Scan
   ↓
4. Role-Specific Processing (existing)
   ↓
5. PIN/Verification (existing)
   ↓
6. Final Processing (existing)
```

## Platform Compatibility

### Mobile Scanner Web Issue Resolution
The implementation uses a platform-aware scanner wrapper to completely avoid mobile_scanner package on web:

```dart
// Platform-aware wrapper
export 'mobile_scanner_impl.dart' if (dart.library.html) 'web_scanner_impl.dart';
```

### Architecture
- **`platform_scanner.dart`**: Conditional export based on platform
- **`mobile_scanner_impl.dart`**: Wraps actual mobile_scanner package for mobile
- **`web_scanner_impl.dart`**: Provides stub classes for web compilation
- **Unified API**: Same interface across all platforms

### Web Platform Handling
- **Web**: Shows fallback UI with clear message that scanning is mobile-only
- **Mobile**: Full QR scanner functionality with schedule validation
- **No Runtime Checks**: Platform detection happens at compile time

### Implementation Details
- No mobile_scanner import on web platform
- Prevents dart:html compilation errors completely
- Unified PlatformScanner API across platforms
- Zero performance impact on mobile

## Files Created/Modified

### New Files
- `lib/services/schedule_validation_service.dart`
- `lib/widgets/schedule_confirmation_dialog.dart`
- `lib/screens/border_configuration_screen.dart`
- `lib/utils/platform_scanner.dart` - Platform-aware scanner wrapper
- `lib/utils/mobile_scanner_impl.dart` - Mobile implementation
- `lib/utils/web_scanner_impl.dart` - Web stub implementation
- `database_migration_out_of_schedule_scans.sql`
- `test_out_of_schedule_scanning.dart`
- `test_platform_scanner_wrapper.dart`

### Modified Files
- `lib/screens/authority_validation_screen.dart` - Added schedule validation + platform scanner
- `lib/screens/border_management_screen.dart` - Added out-of-schedule checkbox to border editing dialog
- `lib/models/border.dart` - Added allowOutOfScheduleScans field
- `lib/services/border_service.dart` - Updated create/update methods for new field
- `lib/widgets/border_management_menu.dart` - Added configuration option (deprecated approach)

## Testing

### Test Files
- `test_out_of_schedule_scanning.dart` - Feature overview and testing
- `test_platform_scanner_wrapper.dart` - Platform scanner wrapper testing

### Manual Testing Steps
1. **Setup**: Run database migration to add new column
2. **Configuration**: Use Border Management → Border Configuration to enable/disable out-of-schedule scans
3. **Scanning**: Test pass scanning as border official outside scheduled hours
4. **Verification**: Check audit logs for out-of-schedule scan entries

## Security & Compliance

### Audit Trail
- All out-of-schedule scans are logged in `audit_logs` table
- Includes full context: pass ID, border ID, schedule details, timestamp
- Immutable audit record for compliance reporting

### Access Control
- Only Border Officials are subject to schedule validation
- Local Authority users are unaffected
- Border configuration requires appropriate management permissions

## Conclusion

This implementation provides a complete solution for managing out-of-schedule pass scanning while maintaining security, compliance, and user experience. The platform-aware scanner wrapper completely resolves mobile_scanner compilation issues on web while maintaining full functionality on mobile devices.

**Key Achievements:**
- ✅ Complete out-of-schedule scanning feature
- ✅ Platform compatibility issues resolved
- ✅ Zero compilation errors on all platforms
- ✅ Full functionality preserved on mobile
- ✅ Graceful degradation on web
- ✅ Comprehensive audit logging
- ✅ User-friendly configuration interface