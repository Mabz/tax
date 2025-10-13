# Troubleshoot Profile Images Not Showing

## 🔍 **Step-by-Step Debugging**

### **Step 1: Check Database Function Update**
Run `debug_profile_images_issue.sql` in Supabase SQL editor to check:
1. If the function was updated to include `profile_image_url`
2. If users actually have profile images in the database
3. What the function returns

### **Step 2: Update Database Function**
If the function wasn't updated, run `add_profile_image_to_authority_profiles.sql` in Supabase SQL editor.

### **Step 3: Check Flutter Debug Output**
After hot restarting the app, check Flutter console when loading "Manage Users":
```
🔍 AuthorityProfiles: Database function returned: X records
🔍 AuthorityProfiles: Sample record: {...}
🔍 AuthorityProfiles: Profile image URL in first record: [URL or null]
```

### **Step 4: Verify Profile Images Exist**
Check if users actually have profile images:
```sql
SELECT 
    email,
    full_name,
    profile_image_url
FROM profiles 
WHERE profile_image_url IS NOT NULL 
AND profile_image_url != ''
LIMIT 5;
```

## **Common Issues & Solutions**

### **Issue 1: Database Function Not Updated**
**Symptoms:** Debug shows `profile_image_url: null` for all records
**Solution:** Run `add_profile_image_to_authority_profiles.sql`

### **Issue 2: No Profile Images in Database**
**Symptoms:** All users have `profile_image_url: null`
**Solution:** Users need to upload profile images first

### **Issue 3: Function Returns Old Structure**
**Symptoms:** Debug shows error about missing `profile_image_url` field
**Solution:** Re-run the database function update

### **Issue 4: ProfileImageWidget Not Loading**
**Symptoms:** Shows placeholder even with valid URLs
**Solution:** Check image URLs are accessible and valid

## **Quick Test Steps**

### **1. Manual Function Test**
```sql
-- Get a sample authority ID first
SELECT authority_id FROM authority_profiles LIMIT 1;

-- Test the function (replace with actual ID)
SELECT 
    profile_email,
    profile_image_url
FROM get_authority_profiles_for_admin('your-authority-id-here')
LIMIT 3;
```

### **2. Check Flutter Debug Output**
Look for these messages in Flutter console:
- `🔍 AuthorityProfiles: Sample record: {...}`
- `🔍 AuthorityProfiles: Profile image URL in first record: [URL]`
- `🔍 AuthorityProfiles: First profile image URL: [URL]`

### **3. Test Profile Image Upload**
1. Go to Profile Settings in your app
2. Upload a profile image for a test user
3. Check if it appears in "Manage Users"

## **Expected Behavior**

### **With Profile Images:**
- Shows actual user photos in cards and dialog
- ProfileImageWidget loads and displays images
- Status indicators appear as small overlays

### **Without Profile Images:**
- Shows default avatar icons (person icon)
- ProfileImageWidget handles gracefully
- Still shows status indicators

## **Debug Commands**

### **Check Function Definition:**
```sql
SELECT routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'get_authority_profiles_for_admin';
```

### **Check Profile Images:**
```sql
SELECT COUNT(*) as total, 
       COUNT(profile_image_url) as with_url,
       COUNT(CASE WHEN profile_image_url IS NOT NULL AND profile_image_url != '' THEN 1 END) as with_actual_images
FROM profiles;
```

### **Test Image URLs:**
If you have image URLs, test them in a browser to ensure they're accessible.

## **Next Steps**

1. **Run Debug Queries**: Execute `debug_profile_images_issue.sql`
2. **Check Flutter Console**: Look for the debug messages
3. **Update Function**: Run `add_profile_image_to_authority_profiles.sql` if needed
4. **Test with Real Images**: Upload profile images for test users
5. **Share Results**: Let me know what the debug output shows

The debug logging will tell us exactly where the issue is! 🔍