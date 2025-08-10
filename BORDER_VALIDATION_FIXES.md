# Border Validation Logic Fixes

## Issues Identified

### 1. Wrong Table Name
**Problem**: Code was using `border_assignments` table, but the actual schema uses `border_official_borders`.

**Impact**: All border assignment queries were failing, causing the system to fall back to authority-level validation only.

### 2. Incorrect Border ID Source
**Problem**: Code was trying to get `border_id` from `pass_templates.border_id`, but the actual border assignment is stored in `purchased_passes.border_id`.

**Impact**: The system couldn't determine which border a pass was for, so border-specific validation wasn't working.

### 3. Logic Mismatch
**Problem**: The validation logic didn't match the actual business requirements based on your schema.

## Fixes Applied

### 1. Updated Table References
**Changed**: All references from `border_assignments` to `border_official_borders`

**Files Updated**:
- `lib/screens/authority_validation_screen.dart`
- `lib/services/border_official_service.dart`
- `border_official_assignments.sql`

### 2. Fixed Border ID Retrieval
**Before**:
```sql
SELECT pass_templates.border_id FROM purchased_passes
JOIN pass_templates ON purchased_passes.pass_template_id = pass_templates.id
```

**After**:
```sql
SELECT border_id FROM purchased_passes
-- Get border_id directly from purchased_passes table
```

### 3. Corrected Validation Logic
**The logic now correctly implements**:

#### For Border Officials:
1. **Authority Check**: Pass must be from the same authority as the official
2. **Border Check**: 
   - If pass has `border_id` (specific border): Official must be assigned to that border OR have admin privileges
   - If pass has no `border_id` (general pass): Allow if same authority

#### For Local Authority:
- Must be from the same country as the authority that issued the pass

## Updated Validation Flow

```
1. Scan QR Code
   ↓
2. Get Pass Details
   - authority_id (from purchased_passes)
   - border_id (from purchased_passes - can be null)
   - country_id (from purchased_passes)
   ↓
3. Check User Authority
   - Must match pass.authority_id
   ↓
4. Check Border Assignment (if pass has border_id)
   - Query border_official_borders table
   - Check if official is assigned to that border
   - OR check if official has admin privileges
   ↓
5. Allow/Deny Access
```

## Database Schema Alignment

### Correct Table Structure:
```sql
-- Border assignments (existing table)
CREATE TABLE border_official_borders (
    id uuid PRIMARY KEY,
    profile_id uuid REFERENCES profiles(id),
    border_id uuid REFERENCES borders(id),
    assigned_by_profile_id uuid REFERENCES profiles(id),
    assigned_at timestamp DEFAULT now(),
    is_active boolean DEFAULT true
);

-- Pass records (existing table)
CREATE TABLE purchased_passes (
    id uuid PRIMARY KEY,
    profile_id uuid REFERENCES profiles(id),
    authority_id uuid REFERENCES authorities(id),
    border_id uuid REFERENCES borders(id), -- Can be null for general passes
    -- ... other fields
);
```

## Test Cases

### Case 1: Specific Border Pass - Official Assigned ✅
- Pass: `border_id = 'border-123'`, `authority_id = 'auth-456'`
- Official: `authority_id = 'auth-456'`, assigned to `border-123`
- **Result**: ALLOW

### Case 2: Specific Border Pass - Official Not Assigned ❌
- Pass: `border_id = 'border-123'`, `authority_id = 'auth-456'`
- Official: `authority_id = 'auth-456'`, assigned to `border-789`
- **Result**: DENY

### Case 3: General Pass - Same Authority ✅
- Pass: `border_id = null`, `authority_id = 'auth-456'`
- Official: `authority_id = 'auth-456'`
- **Result**: ALLOW

### Case 4: General Pass - Different Authority ❌
- Pass: `border_id = null`, `authority_id = 'auth-456'`
- Official: `authority_id = 'auth-789'`
- **Result**: DENY

### Case 5: Specific Border Pass - Admin Privileges ✅
- Pass: `border_id = 'border-123'`, `authority_id = 'auth-456'`
- Official: `authority_id = 'auth-456'`, role = `country_admin`
- **Result**: ALLOW (admin override)

## Files Modified

### Core Logic Files:
1. **`lib/screens/authority_validation_screen.dart`**:
   - Fixed table name in `_canBorderOfficialProcessBorder()`
   - Fixed border ID retrieval in `_getPassAuthorityInfo()`

2. **`lib/services/border_official_service.dart`**:
   - Updated all methods to use `border_official_borders` table
   - Fixed query structures

3. **`border_official_assignments.sql`**:
   - Updated all functions to work with existing schema
   - Fixed table references and column names

### New Test Files:
1. **`test_border_validation_logic.dart`**:
   - Logic test cases
   - Validation pseudocode
   - Test data generation

## Verification Steps

### 1. Test Database Queries
```sql
-- Check if border assignment exists
SELECT * FROM border_official_borders 
WHERE profile_id = 'official-id' 
AND border_id = 'border-id' 
AND is_active = true;

-- Check pass border assignment
SELECT border_id, authority_id FROM purchased_passes 
WHERE id = 'pass-id';
```

### 2. Test App Logic
```dart
// Test border assignment check
final canProcess = await BorderOfficialService.canOfficialProcessBorder(
  'official-profile-id',
  'border-id',
);

// Test pass validation
await QRValidationDebugger.debugQRValidation(qrCodeData);
```

### 3. Check Debug Logs
Look for these messages:
```
✅ Border official is assigned to border: border-123
❌ Border assignment check failed
🔄 Falling back to authority-level validation
```

## Expected Behavior Now

1. **QR Code Recognition**: Should work correctly with proper error messages
2. **Border Assignment**: Officials can only scan passes for their assigned borders
3. **General Passes**: Officials can scan general passes from their authority
4. **Admin Override**: Country admins can scan any pass in their authority
5. **Clear Errors**: Specific error messages explain exactly what's wrong

The system should now correctly implement the border official management logic as per your schema and business requirements.