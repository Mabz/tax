# Google Maps Setup for Web

## Overview
The enhanced border officials heat map now includes Google Maps integration for better visualization of scan locations. While Google Maps works out of the box on Android, web requires additional setup.

## Current Status
- ✅ **Android**: Fully configured and working
- ⚠️ **Web**: Requires Google Maps JavaScript API key

## Web Setup Instructions

### 1. Get Google Maps API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps JavaScript API
   - Geocoding API (optional, for address lookups)
4. Create credentials (API Key)
5. Restrict the API key to your domain for security

### 2. Configure the API Key
Replace `YOUR_GOOGLE_MAPS_API_KEY` in `web/index.html` with your actual API key:

```html
<script async defer src="https://maps.googleapis.com/maps/api/js?key=YOUR_ACTUAL_API_KEY&libraries=geometry,places&loading=async"></script>
```

**Important Notes:**
- The `async defer` attributes improve loading performance
- The `loading=async` parameter is recommended for better performance
- This addresses the Google Maps deprecation warnings

### 3. Security Considerations
- Restrict API key to your domain
- Enable only necessary APIs
- Monitor usage to avoid unexpected charges

## Features

### Enhanced Heat Map Widget
The new `EnhancedBorderOfficialsHeatMap` widget provides:

1. **Interactive Google Maps**
   - Real map tiles with satellite/hybrid view
   - Zoom and pan controls
   - Marker clustering for scan locations

2. **Visual Heat Map**
   - Colored markers (red for outliers, green for normal)
   - Circle overlays showing scan intensity
   - 5km radius circle around border location

3. **Dual View Modes**
   - Map view: Interactive Google Maps
   - List view: Detailed list of scan locations

4. **Smart Filtering**
   - Show all locations or outliers only
   - Outliers are scans >5km from border

5. **Location Details**
   - Click markers or list items for details
   - Shows official name, scan count, distance from border
   - Security alerts for outlier locations

## Usage

### In Border Analytics Screen
The heat map is available in the "Officials" tab and shows:
- All scan locations for the selected border and time period
- Visual representation of where officials are conducting scans
- Identification of potential security concerns (outlier locations)

### Key Benefits
1. **Security Monitoring**: Easily spot scans happening far from expected border areas
2. **Performance Analysis**: See which areas have high scan activity
3. **Geographic Context**: Understand the spatial distribution of border activities
4. **Compliance Checking**: Verify officials are scanning in appropriate locations

## Fallback Behavior
- **Without API Key**: Shows warning message and falls back to list view
- **Mobile Platforms**: Uses native Google Maps (no API key needed)
- **Network Issues**: Graceful degradation to list view
- **API Errors**: Automatic fallback with helpful error messages

## Known Issues & Solutions

### Google Maps Marker Deprecation Warning
You may see this warning in the console:
```
As of February 21st, 2024, google.maps.Marker is deprecated. Please use google.maps.marker.AdvancedMarkerElement instead.
```

**Status**: This is a known issue with the Flutter Google Maps plugin. The warning can be safely ignored as:
- `google.maps.Marker` will continue to work for at least 12 months
- The Flutter team is working on updating to the new API
- Functionality is not affected

### Invalid API Key Errors
If you see `InvalidKeyMapError`, ensure:
1. Your API key is correctly set in `web/index.html`
2. The Maps JavaScript API is enabled in Google Cloud Console
3. Your API key has the correct domain restrictions

## Testing
1. Run on Android to see full functionality
2. For web testing with maps, add your API key to `web/index.html`
3. Use the toggle button to switch between map and list views
4. Test the outlier filter to see security-focused view