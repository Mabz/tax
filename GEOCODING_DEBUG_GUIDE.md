# Geocoding Debug Guide

## Issue
Location names are not showing up in movement history - only coordinates are displayed.

## Debug Steps Applied

### 1. Enhanced Logging
Added comprehensive debug logging to track:
- Coordinate values being passed
- Geocoding API calls
- Placemark data returned
- Cache operations
- Error handling

### 2. Improved Error Handling
- Added connection state checking in FutureBuilder
- Shows "Loading..." while geocoding is in progress
- Shows error state with coordinates as fallback
- Always shows some location info for debugging

### 3. Enhanced Geocoding Logic
- Added locale specification (`en_US`)
- Tries multiple placemark fields for best location description
- Logs all available placemark data for debugging

## How to Debug

### 1. Check Debug Console
Look for these log messages when viewing movement history:
```
🌍 Movement coordinates: -26.3054, 31.1367
🌍 Getting location for: -26.3054, 31.1367
🌍 Calling geocoding API...
🌍 Geocoding returned 1 placemarks
🌍 Placemark details:
  - Name: Some Location
  - Locality: Mbabane
  - AdministrativeArea: Hhohho
  - Country: Eswatini
🌍 Final location name: Mbabane, Hhohho, Eswatini
```

### 2. Check Movement History Display
You should now see one of these states:
- **Success**: "Location: Mbabane, Hhohho, Eswatini"
- **Loading**: "Location: Loading..."
- **Error**: "Location: Error - -26.3054, 31.1367"
- **No GPS**: "Location: No GPS data (0.0, 0.0)"

### 3. Common Issues & Solutions

#### Issue: "No GPS data (0.0, 0.0)"
**Cause**: Coordinates are not being stored in the database
**Solution**: Check if GPS is working when scans are performed

#### Issue: "Location: Loading..." (never resolves)
**Cause**: Geocoding API is not responding
**Solutions**:
- Check internet connection
- Verify geocoding package is working
- Check if coordinates are valid

#### Issue: "Location: Error - [coordinates]"
**Cause**: Geocoding API returned an error
**Solutions**:
- Check debug logs for specific error
- Verify coordinates are within valid ranges
- Check if geocoding service is available

#### Issue: Only coordinates shown
**Cause**: Geocoding succeeded but returned empty placemark data
**Solution**: Check debug logs to see what placemark data is available

### 4. Test Geocoding Manually

You can test geocoding with known coordinates:
- Mbabane, Eswatini: -26.3054, 31.1367
- Johannesburg, SA: -26.2041, 28.0473
- Cape Town, SA: -33.9249, 18.4241

### 5. Verify Database Data

Check if your pass_movements table has proper latitude/longitude data:
```sql
SELECT 
  id, 
  movement_type, 
  latitude, 
  longitude, 
  processed_at 
FROM pass_movements 
WHERE latitude IS NOT NULL 
  AND longitude IS NOT NULL 
  AND latitude != 0 
  AND longitude != 0
ORDER BY processed_at DESC 
LIMIT 5;
```

## Expected Behavior

After the debug improvements:
1. **All movements** should show location info (even if just coordinates)
2. **Debug logs** should show geocoding attempts
3. **Loading states** should be visible during geocoding
4. **Error states** should show coordinates as fallback
5. **Successful geocoding** should show readable location names

## Next Steps

1. **Run the app** and check movement history
2. **Look at debug console** for geocoding logs
3. **Report what you see** - loading, error, or coordinate display
4. **Check database** to verify GPS data is being stored

The enhanced debugging will help identify exactly where the geocoding process is failing.