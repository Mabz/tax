# Google Maps Setup Guide

This guide will help you set up Google Maps integration for the EasyTax border management system.

## Step 1: Get a Google Maps API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Geocoding API
   - Places API (optional, for enhanced location search)

4. Create credentials:
   - Go to "Credentials" in the left sidebar
   - Click "Create Credentials" → "API Key"
   - Copy the generated API key

## Step 2: Configure the API Key

### Environment Configuration
1. Open the `.env` file in the project root
2. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key:
   ```
   GOOGLE_MAPS_API_KEY=AIzaSyBvOkBvgJqcQMuFLjJ8CaElNlA2kkXYZ12
   ```

### Android Configuration
1. Open `android/app/src/main/AndroidManifest.xml`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="AIzaSyBvOkBvgJqcQMuFLjJ8CaElNlA2kkXYZ12" />
   ```

### iOS Configuration
1. Open `ios/Runner/Info.plist`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key:
   ```xml
   <key>GMSApiKey</key>
   <string>AIzaSyBvOkBvgJqcQMuFLjJ8CaElNlA2kkXYZ12</string>
   ```

## Step 3: Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

## Step 4: API Key Restrictions (Recommended)

For security, restrict your API key usage:

1. In Google Cloud Console, go to "Credentials"
2. Click on your API key
3. Under "Application restrictions":
   - For Android: Select "Android apps" and add your package name and SHA-1 certificate fingerprint
   - For iOS: Select "iOS apps" and add your bundle identifier

4. Under "API restrictions":
   - Select "Restrict key"
   - Choose the APIs you enabled earlier

## Step 5: Test the Integration

1. Run the app: `flutter run`
2. Navigate to Border Management
3. Click "Add Border"
4. Click "Select on Map" button
5. The Google Maps interface should load

## Features

The location picker provides different experiences based on platform:

### Mobile (Android/iOS)
- **Interactive Map Selection**: Tap anywhere on the map to select a border location
- **Current Location**: Use GPS to get your current location
- **Address Lookup**: Automatically converts coordinates to readable addresses
- **Draggable Markers**: Fine-tune the exact location by dragging the marker
- **Hybrid Map View**: Shows both satellite imagery and road information (ideal for border locations)

### Web/Desktop (Windows/macOS/Linux)
- **Manual Coordinate Entry**: Enter latitude and longitude directly
- **External Map Integration**: Open Google Maps in browser to find locations
- **Copy-Paste Workflow**: Find coordinates in external maps and paste them back
- **Address Lookup**: Still works for reverse geocoding when coordinates are entered

## Troubleshooting

### Common Issues:

1. **"TargetPlatform.windows not yet supported" on Web/Desktop**: This is expected behavior. The app will automatically show a web-friendly interface with manual coordinate entry and external map links.

2. **Map not loading on mobile**: Check that your API key is correctly configured in all three places (.env, AndroidManifest.xml, Info.plist)

3. **"This page can't load Google Maps correctly"**: Your API key might be restricted or invalid

4. **Location permission denied**: Make sure location permissions are granted in device settings

5. **Geocoding not working**: Ensure the Geocoding API is enabled in Google Cloud Console

### Debug Steps:

1. Check the console logs for API key errors
2. Verify all required APIs are enabled in Google Cloud Console
3. Ensure your API key has the correct restrictions
4. Test with a fresh API key if issues persist

## Cost Considerations

Google Maps APIs have usage-based pricing:
- Maps SDK: $7 per 1,000 map loads
- Geocoding API: $5 per 1,000 requests
- First $200/month is free

For a border management system, typical usage should stay within the free tier.

## Security Best Practices

1. **Never commit API keys to version control**
2. **Use environment variables for API keys**
3. **Restrict API keys to specific apps and APIs**
4. **Monitor usage in Google Cloud Console**
5. **Rotate API keys regularly**

## Next Steps

Once Google Maps is working, you can enhance the system with:
- Geofencing for automatic border detection
- Route planning between borders
- Integration with vehicle tracking
- Historical location data visualization