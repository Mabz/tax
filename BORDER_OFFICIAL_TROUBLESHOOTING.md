# Border Official QR Code Troubleshooting Guide

## Issue: "QR code not recognized" when scanning valid passes

### Possible Causes and Solutions

#### 1. Database Migration Not Applied
**Problem**: The `border_assignments` table doesn't exist yet.
**Solution**: Apply the database migration.

```sql
-- Run this SQL migration on your Supabase instance
-- File: border_official_assignments.sql
```

**How to check**: Look for this error in logs:
```
⚠️ Border assignments table may not exist or error querying: relation "border_assignments" does not exist
```

#### 2. Authority Mismatch
**Problem**: Border official trying to scan pass from different authority.
**Symptoms**: 
- QR code scans but shows "Access denied" message
- Error: "Border officials can only validate passes issued by their own authority"

**Solution**: 
- Verify the border official is assigned to the correct authority
- Check that the pass was issued by the same authority

**Debug steps**:
1. Check current user's authority: Look for log message like `Current user authority: [authority-id]`
2. Check pass authority: Look for log message like `Pass issued by authority: [authority-id]`
3. Ensure they match

#### 3. Border Assignment Issues
**Problem**: Border official not assigned to specific border.
**Symptoms**:
- Error: "You are not assigned to process passes for this specific border"
- Pass is for a specific border but official lacks assignment

**Solutions**:
1. **Assign border official to border** (Country Admin):
   ```dart
   await BorderOfficialService.assignOfficialToBorder(
     officialProfileId,
     borderId,
   );
   ```

2. **Check current assignments**:
   ```dart
   final borders = await BorderOfficialService.getAssignedBordersForOfficial(
     officialProfileId,
   );
   ```

3. **Temporary workaround**: The system falls back to authority-level validation if border assignments table doesn't exist.

#### 4. QR Code Format Issues
**Problem**: QR code data is in unexpected format.
**Debug**: Use the debug helper:

```dart
import 'debug_qr_validation.dart';

// Debug specific QR code
await QRValidationDebugger.debugQRValidation(qrCodeData);
```

**Common formats**:
- JSON: `{"passId":"uuid","hash":"code"}`
- Pipe-delimited: `passId:uuid|hash:code`
- Simple UUID: `12345678-1234-1234-1234-123456789012`

#### 5. Network/Database Issues
**Problem**: Connection problems or database errors.
**Symptoms**:
- "Network error" messages
- Timeouts during validation

**Solutions**:
1. Check internet connection
2. Verify Supabase connection
3. Check database permissions

### Debugging Steps

#### Step 1: Enable Debug Logging
Look for these log messages in your console:

```
🔍 Starting QR code validation...
📱 QR Data length: [number] characters
📱 QR Data preview: [preview]
```

#### Step 2: Check Authority Validation
Look for these messages:

```
📋 Pass Details:
  - Authority ID: [authority-id]
  - Country ID: [country-id]
  - Border ID: [border-id]
👤 Current User:
  - Authority ID: [authority-id]
  - Country ID: [country-id]
  - Role: [role]
```

#### Step 3: Check Border Assignment
Look for these messages:

```
🔍 Checking border assignment for user: [user-id], border: [border-id]
✅ Border official is assigned to border: [border-id]
```

Or:

```
⚠️ Border assignments table may not exist or error querying
🔄 Falling back to authority-level validation (backward compatibility)
```

### Quick Fixes

#### Fix 1: Apply Database Migration
```bash
# In your Supabase dashboard, run the SQL from border_official_assignments.sql
```

#### Fix 2: Assign Border Official to Border
```dart
// As a country admin
await BorderOfficialService.assignOfficialToBorder(
  'border-official-profile-id',
  'border-id',
);
```

#### Fix 3: Check Pass Authority
```dart
// Verify pass details
final pass = await PassService.validatePassByQRCode(qrData);
if (pass != null) {
  print('Pass Authority: ${pass.authorityId}');
  print('Pass Country: ${pass.countryName}');
  print('Pass Border: ${pass.borderName}');
}
```

### Error Message Reference

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "QR code not recognized" | QR format issue or authority mismatch | Check QR format and authority assignment |
| "Access denied: Border officials can only validate passes issued by their own authority" | Authority mismatch | Verify user and pass are from same authority |
| "Access denied: You are not assigned to process passes for this specific border" | Border assignment missing | Assign official to border or use general pass |
| "Unable to verify pass authority information" | Database/network issue | Check connection and database schema |
| "Your account is not assigned to any authority" | User setup issue | Contact administrator to assign authority |

### Testing Tools

#### Test QR Code Validation
```dart
import 'debug_qr_validation.dart';

// Test with your QR code
await QRValidationDebugger.debugQRValidation(yourQRCode);

// Test with sample data
final samples = QRValidationDebugger.generateSampleQRData();
await QRValidationDebugger.debugQRValidation(samples['json_format']);
```

#### Test Border Assignments
```dart
import 'test_border_assignments.dart';

// Run all border assignment tests
await BorderAssignmentTest.runAllTests();

// Test specific functionality
await BorderAssignmentTest.testCanProcessBorder();
```

### Support Information

When contacting support, please provide:

1. **Error message** (exact text)
2. **Debug logs** (console output)
3. **User details**:
   - User role (border_official, country_admin, etc.)
   - Authority ID
   - Country ID
4. **Pass details**:
   - Pass ID (if available)
   - QR code format
   - Authority that issued the pass
5. **Environment**:
   - App version
   - Database migration status

### Prevention

To prevent these issues in the future:

1. **Always apply database migrations** when updating the app
2. **Properly assign border officials** to their designated borders
3. **Test QR code scanning** after any system changes
4. **Monitor debug logs** for early warning signs
5. **Train users** on proper QR code scanning techniques

### Advanced Debugging

For developers, you can add this to your app initialization:

```dart
// Enable detailed logging for border official validation
void enableBorderOfficialDebugging() {
  // Add this to see all validation steps
  debugPrint('🔧 Border Official Debugging Enabled');
  
  // Test database connectivity
  _testDatabaseConnectivity();
  
  // Test user permissions
  _testUserPermissions();
}
```

This troubleshooting guide should help resolve most QR code recognition issues with the enhanced border official management system.