# Comprehensive Save Issue Troubleshooting

## Current Status
- ✅ Database function fix applied (`fix_update_function_simple.sql`)
- ❌ Save functionality still not working
- ✅ Debug logging added to service

## Step-by-Step Debugging

### 1. **Check Flutter Debug Output**
When you try to save, look for these messages in your Flutter console:

```
🔍 AuthorityProfiles: Updating profile [profile-id]
🔍 AuthorityProfiles: Display name: [name]
🔍 AuthorityProfiles: Is active: [true/false]
🔍 AuthorityProfiles: Notes: [notes]
🔍 AuthorityProfiles: Update response: [response]
```

**What to look for:**
- Does it reach the update method?
- What is the actual response from the database?
- Any error messages?

### 2. **Run Database Diagnostics**
Execute these SQL files in order:

#### A. Basic Function Check
```sql
-- Run: debug_save_issue.sql
-- This checks if function exists and you have data to update
```

#### B. RLS Policy Check  
```sql
-- Run: check_rls_policies.sql
-- This checks if RLS policies are blocking updates
```

#### C. Direct Function Test
```sql
-- Run: test_function_directly.sql
-- This tests the function directly in SQL
```

### 3. **Common Issues & Solutions**

#### **Issue A: Function Not Updated**
**Symptoms:** Function still uses old logic
**Check:** Run step 1 in `debug_save_issue.sql`
**Fix:** Re-run `fix_update_function_simple.sql`

#### **Issue B: RLS Policy Blocking**
**Symptoms:** Function returns `false`, no error
**Check:** Run `check_rls_policies.sql`
**Fix:** Update RLS policies (see below)

#### **Issue C: No Authority Profiles**
**Symptoms:** No data to update
**Check:** Run step 2 in `debug_save_issue.sql`
**Fix:** Check if migration worked correctly

#### **Issue D: Permission Denied**
**Symptoms:** Error in Flutter console
**Check:** Run step 3 in `debug_save_issue.sql`
**Fix:** Verify user has country_administrator role

### 4. **Potential RLS Policy Fix**

If RLS is blocking updates, try this fix:

```sql
-- Update RLS policy to be less restrictive for updates
DROP POLICY IF EXISTS "Country admins can manage authority profiles" ON public.authority_profiles;

CREATE POLICY "Country admins can manage authority profiles" ON public.authority_profiles
    FOR ALL USING (
        -- Allow superusers
        is_superuser() OR
        -- Allow country administrators (broad check)
        EXISTS (
            SELECT 1 FROM public.profile_roles pr
            JOIN public.roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name = 'country_administrator'
            AND pr.is_active = true
        )
    );
```

### 5. **Manual Function Test**

Try calling the function directly in SQL:

```sql
-- Get a profile ID first
SELECT id FROM authority_profiles LIMIT 1;

-- Test the function (replace with actual ID)
SELECT update_authority_profile(
    'your-profile-id-here'::uuid,
    'Manual Test Name',
    true,
    'Manual test notes'
);
```

### 6. **Alternative Debugging Approach**

If the function approach doesn't work, we can try direct table updates:

```sql
-- Test direct update (might fail due to RLS)
UPDATE authority_profiles 
SET display_name = 'Direct Update Test'
WHERE id = 'your-profile-id'
RETURNING id, display_name;
```

### 7. **Flutter-Side Debugging**

Add this temporary debug code to your Flutter app:

```dart
// In manage_users_screen.dart, in the save button onPressed
try {
  print('🔍 About to call updateAuthorityProfile');
  print('🔍 Profile ID: ${profile.id}');
  print('🔍 Display Name: ${displayNameController.text.trim()}');
  
  final success = await _authorityProfilesService.updateAuthorityProfile(
    profileId: profile.id,
    displayName: displayNameController.text.trim(),
    isActive: isActive,
    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
  );
  
  print('🔍 Update result: $success');
  Navigator.of(context).pop(success);
} catch (e) {
  print('❌ Update exception: $e');
  print('❌ Exception type: ${e.runtimeType}');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error updating user: $e')),
  );
}
```

## Next Steps

1. **Check Flutter console output** when you try to save
2. **Run the diagnostic SQL queries** to identify the specific issue
3. **Share the debug output** so I can help pinpoint the exact problem

The debug output will tell us exactly where the issue is occurring! 🔍