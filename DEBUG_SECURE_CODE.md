# 🔍 Debug: Secure Code Not Displaying

## 🎯 **Potential Issues**

### **1. Database Schema**
- ✅ Fields added: `secure_code`, `secure_code_expires_at`
- ❓ RPC function might not include new fields
- ❓ Data might not be saved properly

### **2. Data Flow**
- ✅ Model parsing: `PurchasedPass.fromJson()` includes secure code fields
- ✅ Widget display: `_buildProminentSecureCodeSection()` implemented
- ❓ Data fetching: `getPassesForUser()` might not get secure code fields

### **3. Realtime Updates**
- ✅ Realtime subscription exists
- ❓ Updates might not include new fields
- ❓ Widget might not rebuild with new data

## 🔧 **Debugging Steps**

### **Step 1: Check Database**
Run this query in Supabase SQL editor:
```sql
SELECT id, secure_code, secure_code_expires_at 
FROM purchased_passes 
WHERE secure_code IS NOT NULL;
```

### **Step 2: Check Data Fetching**
Add debug logging to see what data is being fetched:
```dart
// In getPassesForUser(), add:
debugPrint('Pass data: ${json.toString()}');
debugPrint('Secure code: ${json['secure_code']}');
debugPrint('Expires at: ${json['secure_code_expires_at']}');
```

### **Step 3: Check Widget Display**
Add debug logging to see if widget is being called:
```dart
// In _buildProminentSecureCodeSection(), add:
debugPrint('Building secure code section for: ${pass.secureCode}');
debugPrint('Has valid code: ${pass.hasValidSecureCode}');
debugPrint('Has expired code: ${pass.hasExpiredSecureCode}');
```

## 🚀 **Quick Fixes Applied**

### **✅ Updated getPassesForUser()**
- Added fallback query with `*` to get all fields
- Includes explicit secure_code fields in query
- Better error handling and logging

### **✅ Enhanced Error Handling**
- RPC function failure now falls back to direct query
- Debug logging to track what's happening
- Graceful degradation if queries fail

## 📋 **Next Steps**

1. **Run the SQL** in `add_secure_code_fields.sql` if not done already
2. **Test secure code generation** in border control
3. **Check My Passes** to see if code appears
4. **Check debug logs** to see what data is being fetched

## 🔍 **Common Issues**

### **Database Not Updated**
- Run `add_secure_code_fields.sql` in Supabase
- Verify fields exist: `\d purchased_passes`

### **RPC Function Outdated**
- Update `get_passes_for_user` to include new fields
- Or rely on fallback query (which should work)

### **Realtime Not Updating**
- Check if realtime subscription includes new fields
- Widget should rebuild when pass data changes

### **Widget Condition**
- Check if `pass.secureCode != null && pass.secureCode!.isNotEmpty`
- Verify `showDetails` is true in My Passes screen