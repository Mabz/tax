# Google SSO Setup Guide

## ✅ COMPLETED
- Android Client ID: `251416196131-d0ajeq5t0af8o940coh9n5rtjthpfas8.apps.googleusercontent.com`
- SHA-1 Fingerprint: `D6:E7:C7:88:35:0B:7F:75:24:6C:03:74:46:6E:10:5E:4B:A4:3A:3D`
- Package Name: `com.example.flutter_supabase_auth`

## 🚨 CRITICAL ISSUES TO FIX

Your Google login is failing because these steps are incomplete:

1. **❌ MISSING: Web OAuth Client** - Required for Supabase integration
2. **❌ MISSING: Google Provider in Supabase** - Not configured yet
3. **❌ INCOMPLETE: iOS Configuration** - Has placeholder values
4. **❌ WRONG: Client ID Usage** - Using Android ID for all platforms

## 1. Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google+ API:
   - Go to "APIs & Services" > "Library"
   - Search for "Google+ API" and enable it

## 2. Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth 2.0 Client IDs"
3. Create credentials for each platform:

### Web Application
- Application type: Web application
- Name: "Flutter Supabase Auth Web"
- Authorized redirect URIs: `https://cydtpwbgzilgrpozvesv.supabase.co/auth/v1/callback`

### Android Application ✅ COMPLETED
- Application type: Android
- Name: "Flutter Supabase Auth Android"
- Package name: `com.example.flutter_supabase_auth`
- SHA-1 certificate fingerprint: `D6:E7:C7:88:35:0B:7F:75:24:6C:03:74:46:6E:10:5E:4B:A4:3A:3D`
- **Client ID:** `251416196131-d0ajeq5t0af8o940coh9n5rtjthpfas8.apps.googleusercontent.com`

### iOS Application
- Application type: iOS
- Name: "Flutter Supabase Auth iOS"
- Bundle ID: `com.example.flutterSupabaseAuth` (or your actual bundle ID)

## 3. Update Your Flutter App

✅ **COMPLETED** - Your Android Client ID has been added:
- Android Client ID: `251416196131-d0ajeq5t0af8o940coh9n5rtjthpfas8.apps.googleusercontent.com`

**Still needed:**
- Web Client ID (for web platform)
- iOS Client ID (for iOS platform)

## 4. Update iOS Configuration

In `ios/Runner/Info.plist`, replace:
```xml
<string>YOUR_REVERSED_CLIENT_ID</string>
```

With your actual reversed client ID (iOS client ID with parts reversed):
```xml
<string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID_HERE</string>
```

## 5. 🚨 CRITICAL: Supabase Configuration (MUST DO FIRST)

**This is likely why your Google login is failing!**

1. Go to your Supabase project dashboard: https://supabase.com/dashboard/project/cydtpwbgzilgrpozvesv
2. Navigate to Authentication > Providers
3. Find Google in the list and enable it
4. You'll need to:
   - Create a **Web Application** OAuth client in Google Cloud Console first
   - Get the Client ID and Client Secret from that Web client
   - Add them to Supabase
5. Set the redirect URL to: `https://cydtpwbgzilgrpozvesv.supabase.co/auth/v1/callback`

**IMPORTANT:** The Android client ID you have won't work with Supabase - you need a Web client ID.

## 6. Test the Integration

Run your Flutter app:
```bash
flutter run
```

The Google Sign-In button should now work and authenticate users through Supabase.

## Troubleshooting Your Current Issue

**Why Google login is failing:**

1. **Missing Web Client ID**: You only have an Android client ID, but Supabase needs a Web client ID
2. **Google Provider Not Enabled**: Supabase doesn't have Google authentication configured
3. **Wrong Client Configuration**: Your Flutter app is trying to use Android client ID for web authentication

**Quick Fix Steps:**

1. **First**: Go to Google Cloud Console and create a **Web Application** OAuth client
2. **Second**: Enable Google provider in Supabase with the Web client credentials
3. **Third**: Update your Flutter app with the correct client IDs
4. **Fourth**: Test the login again

**Common Error Messages:**
- "Invalid client ID" = Wrong client ID type or not configured in Supabase
- "Unauthorized" = Google provider not enabled in Supabase
- "Sign-in failed" = Missing Web client ID or incorrect configuration