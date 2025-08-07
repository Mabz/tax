# Authority Validation Screen

This document describes the Authority Validation Screen implementation for the Cross-Border Tax Platform.

## Overview

The Authority Validation Screen provides a comprehensive solution for both local authorities and border officials to validate and process border passes. It supports two distinct roles with different capabilities:

### Roles

1. **Local Authority** - Can scan and validate passes for verification purposes only
2. **Border Official** - Can scan passes and deduct entries based on validation preferences

## Features

### QR Code Scanning
- Real-time QR code scanning using device camera
- Automatic pass validation against the database
- Visual feedback with scanning overlay

### Backup Code Entry
- Manual entry option when QR codes cannot be scanned
- 8-digit formatted backup codes (XXXX-XXXX format)
- Auto-formatting and validation

### Pass Validation
- Comprehensive pass status checking (active, expired, entries remaining)
- Real-time database validation
- Detailed pass information display

### Entry Deduction (Border Officials Only)
The system supports three validation preferences for entry deduction:

1. **Direct Deduction** - Immediate entry deduction without additional verification
2. **PIN Verification** - Requires pass owner to enter their personal PIN
3. **Secure Code Verification** - Uses dynamically generated secure codes

## User Interface

### Scanning Step
- Camera view with QR code overlay
- Toggle between QR scanning and backup code entry
- Real-time error feedback

### Pass Details Step
- Pass status indicator (valid/invalid)
- Comprehensive pass information:
  - Vehicle details and number plate
  - Entry information and remaining entries
  - Expiration dates and amounts
  - Border and authority information

### Verification Step (Border Officials)
- PIN entry interface for PIN verification
- Secure code display and entry for secure code verification
- Clear instructions for pass owners

### Processing Step
- Loading indicator during database operations
- Progress feedback

### Completion Step
- Success/failure confirmation
- Updated pass information
- Options to scan another pass or exit

## Technical Implementation

### Dependencies
- `qr_code_scanner` - QR code scanning functionality
- `flutter/services` - Input formatting and system services

### Services Integration
- `PassService.validatePassByQRCode()` - QR code validation
- `PassService.validatePassByBackupCode()` - Backup code validation
- `PassService.deductEntry()` - Entry deduction with logging

### State Management
The screen uses a step-based state machine:
- `ValidationStep.scanning` - Initial scanning state
- `ValidationStep.passDetails` - Pass information display
- `ValidationStep.verification` - Additional verification if required
- `ValidationStep.processing` - Database operations
- `ValidationStep.completed` - Final result display

## Navigation

The screen is accessible from the main home screen drawer with two entry points:

1. **Local Authority Validation** - Opens with `AuthorityRole.localAuthority`
2. **Border Control** - Opens with `AuthorityRole.borderOfficial`

## Security Features

- Real-time pass validation against database
- Secure entry deduction with audit logging
- PIN and secure code verification options
- User role-based functionality restrictions

## Error Handling

- Comprehensive error messages for invalid passes
- Network error handling
- QR code parsing error recovery
- Database operation error feedback

## Usage Instructions

### For Local Authorities
1. Select "Local Authority Validation" from the home screen
2. Scan QR code or enter backup code
3. Review pass details and status
4. Complete validation

### For Border Officials
1. Select "Border Control" from the home screen
2. Scan QR code or enter backup code
3. Review pass details and status
4. If pass is valid and has entries remaining:
   - For direct deduction: Entry is automatically deducted
   - For PIN verification: Ask pass owner to enter PIN
   - For secure code: Show generated code to pass owner and ask for confirmation
5. Complete entry deduction

## Database Schema Requirements

The implementation expects the following database tables:
- `purchased_passes` - Main pass records
- `pass_usage_logs` - Entry deduction audit trail
- `pass_templates` - Pass template information
- `authorities` - Authority information
- `countries` - Country information

## Future Enhancements

- Offline mode support
- Biometric verification options
- Advanced reporting and analytics
- Multi-language support
- Enhanced audit trail features