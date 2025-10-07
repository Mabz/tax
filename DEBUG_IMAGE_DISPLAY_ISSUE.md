# Debug Image Display Issue

## Issue: Image uploads but doesn't display

The image uploads successfully but doesn't show in the UI after upload.

## Debugging Steps

### 1. Check Debug Logs
After uploading an image, check the Flutter console for these debug messages:

```
I/flutter: StorageService: Uploading file: {user_id}/profile_image_{timestamp}.jpg
I/flutter: StorageService: Upload successful
I/flutter: StorageService: Generated public URL: https://...
I/flutter: Generated image URL: https://...
I/flutter: Profile updated with image URL
I/flutter: Local state updated with image URL: https://...
I/flutter: ProfileImageWidget: URL changed from null to https://...
I/flutter: Profile image loaded successfully: https://...
```

### 2. Check Supabase Storage
1. Go to your Supabase Dashboard
2. Navigate to Storage > BorderTax bucket
3. Look for a folder with your user ID
4. Verify the image file is there
5. Try accessing the public URL directly in a browser

### 3. Check Database
Run this query in Supabase SQL Editor:
```sql
SELECT profile_image_url FROM profiles WHERE id = auth.uid();
```

### 4. Common Issues & Solutions

#### Issue: Image URL is null in database
**Solution**: The database update failed
- Check if the `profile_image_url` column exists in the profiles table
- Verify RLS policies allow updates

#### Issue: Image URL exists but image doesn't load
**Solution**: URL or permissions issue
- Copy the URL and try opening it in a browser
- Check if the bucket is public
- Verify the file exists in storage

#### Issue: Image loads in browser but not in app
**Solution**: Caching or widget issue
- The app now includes cache-busting headers
- The widget has a ValueKey to force rebuilds
- Try hot restart instead of hot reload

#### Issue: Widget doesn't refresh after upload
**Solution**: State management issue
- The widget now calls `onImageUpdated` twice (immediate + delayed)
- Check if `_loadProfileData()` is being called in the parent

### 5. Manual Test
You can manually test the image display by temporarily hardcoding a URL:

```dart
// In ProfileImageWidget, temporarily replace:
currentImageUrl: _profileData!['profile_image_url']?.toString(),

// With a known working image URL:
currentImageUrl: 'https://your-supabase-url.supabase.co/storage/v1/object/public/BorderTax/test-image.jpg',
```

### 6. Force Refresh
If the image still doesn't show, try adding this to the Profile Settings screen:

```dart
// Add a refresh button temporarily
FloatingActionButton(
  onPressed: () {
    setState(() {
      _loadProfileData();
    });
  },
  child: Icon(Icons.refresh),
)
```

## Expected Behavior

After upload:
1. ✅ Success message appears
2. ✅ Loading indicator disappears  
3. ✅ Profile image shows the new image
4. ✅ Image persists after app restart

## Next Steps

1. **Upload an image** and check the debug logs
2. **Verify the file** exists in Supabase Storage
3. **Check the database** has the correct URL
4. **Test the URL** directly in a browser
5. **Report findings** - which step is failing?

The debugging output will help identify exactly where the issue occurs in the upload → display pipeline.