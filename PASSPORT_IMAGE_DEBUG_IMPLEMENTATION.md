# Passport Image Debug Implementation

## 🔧 **Changes Made**

### **Enhanced Owner Details Popup**
- Added comprehensive debugging for passport document URL detection
- Improved passport URL validation (handles null, empty, and 'null' string values)
- Enhanced error handling with detailed error messages
- Added loading states for passport image display

### **Debug Features Added**
1. **Console Logging**: Prints owner data keys and passport URL values
2. **URL Validation**: Checks for null, empty, and 'null' string values
3. **Error Display**: Shows actual URL in error messages for debugging
4. **Loading States**: Shows loading indicator while passport image loads

### **Updated Logic**
```dart
// Before: Simple null check
if (_ownerData!['passport_document_url'] != null)

// After: Comprehensive validation
final passportUrl = _ownerData!['passport_document_url']?.toString();
final hasPassportUrl = passportUrl != null && 
                       passportUrl.isNotEmpty && 
                       passportUrl != 'null';
```

## 🔍 **Debugging Steps**

### **1. Check Database**
Run the debug SQL script to check:
```sql
-- Check if passport documents exist in database
SELECT COUNT(*) as total_profiles,
       COUNT(passport_document_url) as profiles_with_passport_url
FROM profiles;
```

### **2. Check Console Output**
When opening Owner Details popup, look for:
```
🔍 Owner Data Keys: [id, full_name, email, ...]
🔍 Passport Document URL: [actual_value]
🔍 Passport Document URL Type: String/Null
🔍 Has Passport URL: true/false
🔍 Passport URL Value: [actual_url]
🖼️ Building passport image section with URL: [url]
```

### **3. Test Cases**
- **Case 1**: Profile with valid passport URL → Should show passport image
- **Case 2**: Profile with null passport URL → Should not show passport section
- **Case 3**: Profile with empty string → Should not show passport section
- **Case 4**: Profile with 'null' string → Should not show passport section

## 📱 **Expected UI Behavior**

### **With Passport Document**
```
┌─ Owner Details ─────────────────────────┐
│ [Profile Photo] Bob Miller              │
│ bob@gmail.com • Vehicle Owner           │
│                                         │
│ ┌─ Passport Page ─────────────────────┐ │ ← SHOULD APPEAR
│ │ [Passport Image - 4.9:3.4 ratio]   │ │
│ │ [View Full Size Button]             │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Personal Information...                 │
│ Identity Documents...                   │
│ Contact Information...                  │
│                                         │
│ ┌─ Passport Information ──────────────┐ │
│ │ Passport Number: [Number]           │ │
│ │ Document Status: Uploaded           │ │ ← SHOULD SHOW "Uploaded"
│ │ Document URL: [URL]                 │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### **Without Passport Document**
```
┌─ Owner Details ─────────────────────────┐
│ [Profile Photo] Bob Miller              │
│ bob@gmail.com • Vehicle Owner           │
│                                         │
│ Personal Information...                 │
│ Identity Documents...                   │
│ Contact Information...                  │
│                                         │
│ ┌─ Passport Information ──────────────┐ │
│ │ Passport Number: [Number]           │ │
│ │ Document Status: Not uploaded       │ │ ← SHOULD SHOW "Not uploaded"
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 🚀 **Testing Instructions**

### **Step 1: Run Debug SQL**
```bash
# Execute the debug script to check database state
psql -f debug_passport_documents.sql
```

### **Step 2: Test Owner Details**
1. Open the app
2. Navigate to vehicle details
3. Click "View Complete Owner Details"
4. Check console output for debug messages
5. Look for passport image section

### **Step 3: Verify Functionality**
- **If passport image appears**: Click "View Full Size" to test full-screen viewer
- **If passport image doesn't appear**: Check console logs for URL values
- **If error appears**: Note the error message and URL shown

## 🔧 **Troubleshooting**

### **Issue: Passport section not showing**
**Check:**
1. Console logs for passport URL value
2. Database for actual passport_document_url values
3. Authority permissions (only authorities can view owner details)

### **Issue: Image loading error**
**Check:**
1. URL format and accessibility
2. Network connectivity
3. Storage bucket permissions (if using Supabase storage)

### **Issue: Function access denied**
**Solution:**
- Ensure you're logged in as an authority user
- Check authority_profiles table for your user ID

## 📊 **Database Verification**

### **Check Passport Documents**
```sql
-- See profiles with passport documents
SELECT full_name, passport_number, passport_document_url
FROM profiles 
WHERE passport_document_url IS NOT NULL 
AND passport_document_url != '';
```

### **Test Authority Function**
```sql
-- Test the function (replace UUID with actual profile ID)
SELECT * FROM get_owner_profile_for_authority('PROFILE_UUID_HERE');
```

## ✅ **Success Criteria**

1. **Debug logs appear** in console when opening owner details
2. **Passport section shows** when passport_document_url exists
3. **Image loads properly** with correct aspect ratio
4. **Full-size viewer works** when clicking "View Full Size"
5. **Error handling works** for invalid URLs
6. **Status shows correctly** (Uploaded/Not uploaded)

The passport image should now be visible in the Owner Details popup with comprehensive debugging to help identify any issues!