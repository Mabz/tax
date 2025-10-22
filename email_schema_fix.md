# Email Schema Fix: Authority Profiles

## Problem Identified
```
PostgrestException: column authority_profiles.email does not exist
```

The `authority_profiles` table doesn't have an `email` column.

## Solution Applied

### 1. Removed Email from Authority Profiles Query
**Before:**
```dart
.select('profile_id, display_name, email, profile_picture_url, is_active, position, department')
```

**After:**
```dart
.select('profile_id, display_name, profile_picture_url, is_active, position, department')
```

### 2. Enhanced Data Merging Strategy
Now the service:
1. **First**: Gets `display_name`, `profile_picture_url`, `position`, `department` from `authority_profiles`
2. **Then**: Gets `full_name`, `email` from `profiles` table for ALL officials
3. **Merges**: The data to create complete official profiles

### 3. Implementation Logic
```dart
// Get authority-specific data (display_name, position, etc.)
authority_profiles: {
  display_name, profile_picture_url, position, department
}

// Get basic profile data (full_name, email) for ALL officials
profiles: {
  full_name, email, is_active
}

// Merge the data:
final_profile = {
  display_name: from authority_profiles (preferred)
  full_name: from profiles (fallback name)
  email: from profiles
  profile_picture_url: from authority_profiles
  position: from authority_profiles
  department: from authority_profiles
}
```

## Database Schema Understanding
```sql
-- authority_profiles table (border officials):
CREATE TABLE authority_profiles (
  profile_id UUID,
  display_name TEXT,        -- ✅ Available (preferred name)
  profile_picture_url TEXT, -- ✅ Available
  is_active BOOLEAN,        -- ✅ Available
  position TEXT,            -- ✅ Available
  department TEXT           -- ✅ Available
  -- email TEXT             -- ❌ Not available
  -- full_name TEXT         -- ❌ Not available
);

-- profiles table (all users):
CREATE TABLE profiles (
  id UUID,
  full_name TEXT,           -- ✅ Available (fallback name)
  email TEXT,               -- ✅ Available
  is_active BOOLEAN         -- ✅ Available
);
```

## Expected Results
- ✅ No more database errors
- ✅ Proper display names for border officials
- ✅ Email addresses from profiles table
- ✅ Complete official information with position/department
- ✅ Fallback to full_name when display_name not available

This fix ensures the service works with the actual database schema while getting the best available data from both tables.