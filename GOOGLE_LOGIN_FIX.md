# 🚨 URGENT: Fix Your Google Login

Your Google login is failing because you're missing critical configuration steps. Here's exactly what you need to do:

## Step 1: Create Web OAuth Client (REQUIRED)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to "APIs & Services" > "Credentials"
4. Click "Create Credentials" > "OAuth 2.0 Client IDs"
5. Choose "Web application"
6. Name it "Flutter Supabase Auth Web"
7. Add this to "Authorized redirect URIs":
   ```
   https://cydtpwbgzilgrpozvesv.supabase.co/auth/v1/callback
   ```
8. Click "Create"
9. **COPY THE CLIENT ID AND SECRET** - you'll need both!

## Step 2: Enable Google Provider in Supabase (CRITICAL)

1. Go to: https://supabase.com/dashboard/project/cydtpwbgzilgrpozvesv/auth/providers
2. Find "Google" in the list
3. Toggle it ON
4. Enter your **Web Client ID** (from Step 1)
5. Enter your **Web Client Secret** (from Step 1)
6. The redirect URL should already be: `https://cydtpwbgzilgrpozvesv.supabase.co/auth/v1/callback`
7. Click "Save"

## Step 3: Update Your Flutter Code

Replace the client ID in your auth_screen.dart with the **Web Client ID** from Step 1:

```dart
const webClientId = 'YOUR_WEB_CLIENT_ID_HERE'; // Replace with actual Web Client ID

final GoogleSignIn googleSignIn = GoogleSignIn(
  serverClientId: webClientId, // Use Web Client ID here
);
```

## Step 4: Test Again

After completing all steps above, your Google login should work!

## Why It Was Failing

- ❌ You only had an Android Client ID
- ❌ Supabase needs a Web Client ID to work
- ❌ Google provider wasn't enabled in Supabase
- ❌ No client secret configured

## Current Status

✅ Android Client ID: `251416196131-d0ajeq5t0af8o940coh9n5rtjthpfas8.apps.googleusercontent.com`
✅ SHA-1 Fingerprint: `D6:E7:C7:88:35:0B:7F:75:24:6C:03:74:46:6E:10:5E:4B:A4:3A:3D`
❌ Web Client ID: **MISSING - CREATE THIS FIRST**
❌ Supabase Google Provider: **NOT ENABLED**

Complete Steps 1-3 above and your Google login will work!