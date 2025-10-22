# Scan Count & Profile Picture Fixes

## Issues Addressed

### 1. Scan Count Discrepancy 
**Problem**: Bobby shows 16 scans but overview shows 6 scans
**Root Cause**: Need to verify both are using the same filtered dataset and timeframe

### 2. Profile Pictures Missing
**Problem**: No profile pictures showing for officials
**Solution**: Get profile_picture_url from profiles table

## Fixes Applied

### 1. Enhanced Debug Logging
Added logging to show:
- How many scans each official has in the filtered dataset
- Date range of those scans
- This will help identify if the discrepancy is due to timeframe filtering

```dart
debugPrint('👤 Official $officialName has ${totalScans} scans in the filtered dataset');
debugPrint('👤 Scan dates range: ${firstScan} to ${lastScan}');
```

### 2. Profile Picture Support
**Updated profiles query:**
```dart
.select('id, full_name, email, profile_picture_url, is_active')
```

**Updated data merging:**
```dart
profilesData[profileId]!['profile_picture_url'] = profile['profile_picture_url'];
```

**Updated official creation:**
```dart
final profilePictureUrl = profile?['profile_picture_url']; // Get from profiles table
```

## Expected Results

### Scan Count Analysis
The debug logs will show:
- If Bobby's 16 scans are all within the 7-day period
- If the overview's 6 scans are using different filtering
- The actual date range of Bobby's scans

### Profile Pictures
- ✅ Bobby's profile picture should now appear (if he has one in profiles table)
- ✅ All officials should show their profile pictures from profiles table
- ✅ Fallback to default icon if no profile picture available

## Movement Types Included
The service currently includes these movement types as "scans":
- `verification_scan`
- `scan_attempt` 
- `border_scan`
- `check_in`
- `check_out`

This means Bobby's 16 scans could include both check-ins and check-outs, which might explain why it's higher than expected.

## Next Steps
1. **Refresh Officials tab** and check console logs
2. **Look for debug messages** showing Bobby's scan details
3. **Verify profile pictures** appear for officials
4. **Analyze if scan counts make sense** based on the date ranges shown

The debug logs will tell us exactly what's causing the scan count discrepancy!