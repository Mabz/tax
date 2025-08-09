# 🔧 Secure Code Troubleshooting Guide

## 🎯 **Issue: Secure Code Not Displaying in My Passes**

The secure code section isn't showing up in the My Passes screen. Let's debug this step by step.

## 🔍 **Debug Steps**

### **Step 1: Verify Database Schema**
Run this in your Supabase SQL editor:
```sql
-- Check if columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'purchased_passes' 
AND column_name IN ('secure_code', 'secure_code_expires_at');

-- Check if any passes have secure codes
SELECT id, secure_code, secure_code_expires_at, created_at
FROM purchased_passes 
WHERE secure_code IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;
```

### **Step 2: Test Secure Code Generation**
1. Go to Border Control
2. Scan a pass with "Secure Code" verification preference
3. Check if code is generated and saved to database
4. Look for these debug logs in Flutter console:
   ```
   🔐 Generated secure code: 123
   💾 Secure code saved to database, expires at: [timestamp]
   ```

### **Step 3: Check Data Fetching**
1. Go to My Passes screen
2. Look for these debug logs in Flutter console:
   ```
   🔍 RPC returned X passes
   📋 Found secure code in RPC data: 123 expires: [timestamp]
   ```
   OR
   ```
   🔍 Fallback query returned X passes
   📋 Found secure code in fallback data: 123 expires: [timestamp]
   ```

### **Step 4: Check Widget Display**
1. If data is being fetched correctly, look for these logs:
   ```
   🔍 Building secure code section for pass: [pass-id]
   📋 Secure code: 123
   📋 Expires at: [timestamp]
   📋 Has valid: true/false
   📋 Has expired: true/false
   ```

## 🚨 **Common Issues & Solutions**

### **❌ Database Schema Not Updated**
**Symptoms:** No secure code data in database queries
**Solution:** Run `add_secure_code_fields.sql` in Supabase SQL editor

### **❌ RPC Function Doesn't Include New Fields**
**Symptoms:** RPC query works but no secure code data
**Solution:** The fallback query should work automatically

### **❌ Secure Code Not Being Saved**
**Symptoms:** Border control generates code but database shows NULL
**Solution:** Check authority validation screen logs for save errors

### **❌ Widget Condition Not Met**
**Symptoms:** Data exists but widget doesn't show
**Solution:** Check if `showDetails` is true and `pass.secureCode` is not null

### **❌ Realtime Updates Not Working**
**Symptoms:** Code exists in database but doesn't appear until app restart
**Solution:** Check realtime subscription and widget rebuilding

## 🔧 **Quick Fixes**

### **Fix 1: Force Fallback Query**
If RPC function is the issue, you can temporarily disable it:
```dart
// In getPassesForUser(), comment out the RPC try block
// This will force the fallback query which includes all fields
```

### **Fix 2: Manual Database Check**
Run this query to manually add a test secure code:
```sql
UPDATE purchased_passes 
SET secure_code = '123', 
    secure_code_expires_at = NOW() + INTERVAL '5 minutes'
WHERE id = 'your-pass-id';
```

### **Fix 3: Check Widget Condition**
Add this debug in PassCardWidget build method:
```dart
debugPrint('Pass ${pass.passId}: showDetails=$showDetails, secureCode=${pass.secureCode}');
```

## 📋 **Expected Behavior**

### **When Working Correctly:**
1. **Border official scans pass** → Code saved to database
2. **User opens My Passes** → Data fetched with secure code
3. **Widget builds** → Prominent secure code section appears
4. **Code expires** → Widget updates to show expired state

### **Debug Log Sequence:**
```
🔐 Generated secure code: 123
💾 Secure code saved to database, expires at: 2024-01-01T12:05:00Z
🔍 RPC returned 3 passes
📋 Found secure code in RPC data: 123 expires: 2024-01-01T12:05:00Z
🔍 Building secure code section for pass: abc-123
📋 Secure code: 123
📋 Expires at: 2024-01-01T12:05:00Z
📋 Has valid: true
📋 Has expired: false
```

## 🚀 **Next Steps**

1. **Run Step 1** to verify database schema
2. **Run Step 2** to test code generation
3. **Check Flutter console** for debug logs
4. **Report findings** - which step shows the issue

The debug logs will help pinpoint exactly where the problem is occurring!