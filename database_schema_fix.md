# Database Schema Fix: Authority Profiles

## Problem Identified
```
PostgrestException: column authority_profiles.full_name does not exist
```

The `authority_profiles` table doesn't have a `full_name` column - it only has `display_name`.

## Root Cause
The service was trying to query both `full_name` and `display_name` from `authority_profiles`, but the table schema only includes `display_name`.

## Solution Applied

### 1. Updated Authority Profiles Query
**Before:**
```dart
.select('profile_id, full_name, display_name, email, profile_picture_url, is_active, position, department')
```

**After:**
```dart
.select('profile_id, display_name, email, profile_picture_url, is_active, position, department')
```

### 2. Enhanced Name Resolution Logic
**New Priority System:**
1. **display_name** from `authority_profiles` (preferred for border officials)
2. **full_name** from `profiles` table (fallback for regular users)
3. **"Border Official [ID]"** (last resort)

### 3. Implementation Details
```dart
String officialName;
if (profile?['source'] == 'authority_profiles' && profile?['display_name'] != null) {
  officialName = profile!['display_name'];  // Use display_name from authority_profiles
} else if (profile?['full_name'] != null) {
  officialName = profile!['full_name'];     // Fallback to full_name from profiles
} else {
  officialName = 'Border Official ${profileId.substring(0, 8)}';  // Last resort
}
```

## Expected Results
- ✅ No more database errors
- ✅ Proper display names for border officials (e.g., "Bobby", "Mark Smith")
- ✅ Fallback to full names for users not in authority_profiles
- ✅ Consistent name resolution across all components

## Database Schema Assumption
```sql
-- authority_profiles table structure:
CREATE TABLE authority_profiles (
  profile_id UUID,
  display_name TEXT,        -- ✅ Available
  email TEXT,
  profile_picture_url TEXT,
  is_active BOOLEAN,
  position TEXT,
  department TEXT
  -- full_name TEXT         -- ❌ Not available
);

-- profiles table structure:
CREATE TABLE profiles (
  id UUID,
  full_name TEXT,           -- ✅ Available as fallback
  email TEXT,
  is_active BOOLEAN
);
```

This fix ensures the service works with the actual database schema while providing the best possible names for border officials.