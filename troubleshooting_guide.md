# Troubleshooting Guide: Border Officials Data Issues

## Current Problem
- Scan counts don't match (Overview: 6, Individual: 16)
- Official names show as "Border Official c4f0f0a4" instead of display names
- Data appears to be using mock/fallback data

## Root Cause Analysis

### Most Likely Issue: Mock Data Being Used
The service is probably falling back to mock data because:
1. **No valid officials found in scan data**
2. **Missing profile_id/created_by fields in pass_movements table**
3. **Scan data doesn't contain proper official references**

## Debug Steps

### 1. Check Console Logs
After refreshing the Officials tab, look for these debug messages:

#### Expected Real Data Flow:
```
🔍 Query completed: Found X records
🔍 Sample records with ALL fields:
🔍   Record 1: {id: xxx, profile_id: xxx, created_by: xxx, ...}
👥 Processing X scan records for officials...
👥 Scan record: profile_id=xxx, created_by=xxx, resolved_id=xxx
👥 Retrieved X authority profiles
👤 Processing official xxx: {display_name: Name, ...}
👤 Official name resolved to: Display Name
```

#### If Mock Data is Used:
```
🔍 Query completed: Found X records
👥 Processing X scan records for officials...
👥 Scan record: profile_id=null, created_by=null, resolved_id=null
👥 ⚠️ Scan record has no valid profile_id or created_by field
👥 ❌ No officials found in scan data, generating mock officials
👥 ❌ Reason: No valid profile_id or created_by fields found in X scan records
```

### 2. Database Schema Check
The issue might be in the `pass_movements` table structure. Check if these columns exist:

```sql
-- Check table structure
DESCRIBE pass_movements;

-- Check for official reference fields
SELECT 
  profile_id, 
  created_by, 
  movement_type, 
  created_at 
FROM pass_movements 
LIMIT 5;
```

### 3. Possible Database Issues

#### Missing Columns:
- `profile_id` column doesn't exist in `pass_movements`
- `created_by` column doesn't exist in `pass_movements`
- Officials aren't properly linked to scan records

#### Data Issues:
- All `profile_id` and `created_by` fields are NULL
- Scan records don't reference actual officials
- Wrong table being queried for scan data

## Solutions

### If profile_id/created_by are missing:
1. **Add the missing columns** to `pass_movements` table
2. **Update existing records** to link them to officials
3. **Modify the query** to use a different field for official identification

### If columns exist but are NULL:
1. **Update scan records** to include proper official references
2. **Check the scanning process** to ensure it records the official who performed the scan
3. **Verify data integrity** in the pass_movements table

### Quick Fix (Temporary):
If the real data structure is different, we can modify the query to use alternative fields:

```dart
// Instead of profile_id/created_by, maybe use:
final officialId = scan['scanned_by'] ?? 
                  scan['official_id'] ?? 
                  scan['user_id'] ?? 
                  'unknown';
```

## Testing Steps

1. **Refresh the Officials tab**
2. **Check console for debug logs**
3. **Identify if mock data is being used**
4. **Check database schema if needed**
5. **Verify scan records have official references**

## Expected Fix Results
Once the proper official references are available:
- ✅ Real official names from authority_profiles
- ✅ Accurate scan counts matching overview
- ✅ Proper profile pictures
- ✅ Consistent data across all metrics

The debug logs will tell us exactly what's wrong and guide us to the right solution!