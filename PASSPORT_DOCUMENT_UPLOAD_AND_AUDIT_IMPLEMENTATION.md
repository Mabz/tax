# Passport Photo Upload and Profile Audit Implementation

## Overview
Implemented camera-based passport photo upload functionality and comprehensive profile settings audit tracking system.

## Database Changes

### 1. Passport Photo Storage
- Added `passport_document_url` column to `profiles` table
- Stores URL of uploaded passport photo (JPG, PNG)

### 2. Profile Settings Audit System
- Created `profile_settings_audit` table to track all profile changes
- Tracks field-level changes with old/new values
- Includes metadata: timestamp, changed_by, change_type, notes
- Implements Row Level Security (RLS) for data protection

### 3. Database Functions
- `log_profile_change()` - Logs individual field changes
- `update_passport_document_url()` - Updates passport photo with audit
- `remove_passport_document()` - Removes passport photo with audit
- `get_profile_audit_history()` - Retrieves audit history for a profile
- Updated existing functions to include audit logging:
  - `update_personal_information()`
  - `update_identity_documents()`

## Frontend Implementation

### 1. Passport Image Widget (`lib/widgets/passport_image_widget.dart`)
- Camera-based passport photo capture
- Reuses existing image picker infrastructure
- Features:
  - Camera and gallery options
  - Photo preview functionality
  - Edit/remove options
  - Error handling and loading states
  - Full-screen photo viewer

### 2. Storage Service Updates (`lib/services/storage_service.dart`)
- Added `uploadPassportImage()` method for passport photos
- Added `uploadPassportImageFromBytes()` for web compatibility
- Maintains user-specific file organization with `passport_` prefix
- Reuses existing `deleteFile()` method for removal

### 3. Profile Management Service Updates (`lib/services/profile_management_service.dart`)
- Added `passport_document_url` to profile data selection
- Added `updatePassportDocumentUrl()` method
- Added `removePassportDocument()` method
- Added `getProfileAuditHistory()` method

### 4. Profile Settings Screen Updates (`lib/screens/profile_settings_screen.dart`)
- Added 4th tab: "Audit" for viewing change history
- Added passport photo section in Identity tab
- Integrated PassportImageWidget
- Added comprehensive audit history display with:
  - Change type indicators (create/update/delete)
  - Before/after value comparison
  - Timestamp and user information
  - Notes and context
  - Formatted field names and values

## Features

### Passport Photo Upload
- Take passport photos using device camera
- Choose from gallery as alternative
- Secure storage in user-specific folders
- Photo preview and full-screen viewing
- Easy edit/remove options
- Automatic audit logging

### Profile Audit History
- Complete change tracking for all profile fields
- Visual change indicators with color coding
- Before/after value comparison
- Timestamp and user attribution
- Special formatting for sensitive fields (PIN shows as ***)
- Empty state handling
- Error state handling

### Security Features
- Row Level Security on audit table
- User can only see their own audit records
- Authority users can see audit records for profiles in their authority
- File access restricted to file owners
- Audit logging for all profile changes

## No Additional Dependencies Required
- Uses existing camera/image picker infrastructure
- No need for file_picker package
- Leverages existing ImagePickerService

## Database Migration
Run the SQL file: `add_passport_document_upload.sql`

## Usage

### For Users
1. Go to Profile Settings → Identity tab
2. Scroll to "Passport Photo" section
3. Tap to take a photo of your passport
4. View change history in Audit tab

### For Developers
```dart
// Upload passport photo
await ProfileManagementService.updatePassportDocumentUrl(imageUrl);

// Remove passport photo
await ProfileManagementService.removePassportDocument();

// Get audit history
final history = await ProfileManagementService.getProfileAuditHistory();
```

## Benefits
1. **Compliance**: Complete audit trail for regulatory requirements
2. **Security**: Track unauthorized changes and access
3. **User Experience**: Simple camera-based photo capture
4. **Transparency**: Users can see their own change history
5. **Administration**: Authority users can monitor profile changes
6. **Data Integrity**: Automatic logging prevents data loss tracking
7. **Mobile-First**: Optimized for mobile camera usage

## Implementation Highlights
- **Camera Integration**: Uses existing robust camera infrastructure
- **No File Picker**: Simplified approach using camera/gallery only
- **Consistent Storage**: Files stored with `passport_` prefix for easy identification
- **Audit Trail**: Every change is logged with context and metadata
- **Security**: RLS policies ensure data privacy and access control

## Next Steps
1. Run database migration
2. Test passport photo functionality
3. Verify audit logging works correctly
4. Consider adding photo quality guidelines
5. Add export functionality for audit reports