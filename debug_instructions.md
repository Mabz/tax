# Debug Instructions for Border Analytics Issues

## Steps to Test the Fixes

### 1. **Check Debug Logs**
After making the changes, when you navigate to the Border Analytics > Officials tab, you should see debug logs in the console like:

```
🔍 Query completed: Found X records
🔍 First few scan records:
🔍   Scan 1: 2024-XX-XX - Profile: profile-id - Movement: movement-type
👤 Processing official profile-id: {display_name: Name, full_name: Full Name, ...}
👤 Official name resolved to: Display Name
📊 Overview Metrics Calculation:
📊 Total scan records: X
📊 Scans today: X
📊 Scans this week: X
📊 Active officials: X
```

### 2. **Force Refresh Data**
1. Go to Border Analytics screen
2. Switch to the "Officials" tab
3. Click the **refresh button** (🔄) in the top-right corner
4. Watch the console for debug logs

### 3. **Check for Issues**

#### Issue A: Scan Count Discrepancy
- **Expected**: Total scans in overview should equal sum of individual official scans
- **Debug**: Look for "📊 Total scan records" in logs
- **If still wrong**: The scan data filtering might need adjustment

#### Issue B: Official Names
- **Expected**: Should show display names like "Bobby", "Mark Smith"
- **Debug**: Look for "👤 Official name resolved to" in logs
- **If still wrong**: Check if display_name field exists in authority_profiles table

### 4. **Possible Issues & Solutions**

#### If No Debug Logs Appear:
- The service might not be called
- Check if there are compilation errors
- Try hot restart instead of hot reload

#### If Display Names Still Don't Show:
- Check if `display_name` column exists in `authority_profiles` table
- Verify the officials are in `authority_profiles` (not just `profiles`)
- Check if the query is returning data

#### If Scan Counts Still Don't Match:
- Check the date range filtering logic
- Verify the same `scanData` is used for both overview and individual calculations

### 5. **Database Check**
Run this query to verify display names exist:
```sql
SELECT profile_id, full_name, display_name, position 
FROM authority_profiles 
WHERE is_active = true;
```

### 6. **Manual Test**
1. Navigate to Border Analytics
2. Select Officials tab
3. Note the total scans number in the overview
4. Expand an official and note their scan count
5. The overview total should be >= individual official scans

## Expected Results After Fix:
- ✅ Overview scan count = sum of all individual official scans
- ✅ Official names show as "Bobby", "Mark Smith" (display names)
- ✅ Debug logs show proper data processing
- ✅ Refresh button updates data correctly

## If Issues Persist:
1. Check console for debug logs
2. Verify database schema has display_name column
3. Ensure officials are in authority_profiles table
4. Try clearing app cache/storage
5. Check if there are any error messages in logs