# QR Code Simplification Summary

## Problem
The database was storing complex JSON data in the `qr_data` column with all pass details, making QR codes unnecessarily large and complex:

```json
{
  "id": "c6b6832d-9592-4b00-9601-287796f6f7cd",
  "amount": 150,
  "currency": "SZL",
  "issued_at": "2025-10-07T00:00:00.000",
  "pass_hash": "001EJVIX",
  "country_id": "c72799ff-a182-4417-89b3-ab13095b00e4",
  "expires_at": "2025-11-06T00:00:00.000",
  "profile_id": "cbf0f0a4-2d6d-4496-b944-f69c39aeecc2",
  "short_code": "001E-JVIX",
  "entry_limit": 5,
  "vehicle_vin": "12345678901234567",
  "authority_id": "1c84f0eb-95e0-4aa4-b6ab-213c30af6595",
  // ... and many more fields
}
```

## Solution
Simplified QR data to contain **only the pass ID**:

```json
{
  "id": "c6b6832d-9592-4b00-9601-287796f6f7cd"
}
```

## What Was Fixed

### 1. App Code (Already Correct)
Your Flutter app was already generating simple QR codes:
- **pass_dashboard_screen.dart** (line 488): Generates QR with just `pass.passId`
- **pass_service.dart** (line 463-465): Stores simple format `{"id": actualPassId}`
- **pass_verification_service.dart**: Handles both JSON and plain UUID formats

### 2. Database Fix (New SQL Script)
Created `simplify_qr_data.sql` to:
- Remove any triggers auto-generating complex QR data
- Update all existing passes to simple format
- Add documentation to the column

## How to Apply the Fix

### Option 1: Supabase Dashboard
1. Open your Supabase dashboard
2. Go to **SQL Editor**
3. Copy and paste the contents of `simplify_qr_data.sql`
4. Click **Run**

### Option 2: Supabase CLI
```bash
supabase db execute -f simplify_qr_data.sql
```

## Benefits

1. **Smaller QR Codes**: Easier to scan, especially on phones
2. **Faster Scanning**: Less data to process
3. **Unified Scanner**: Both Local Authority and Border Control use the same simple format
4. **Better Reliability**: Simpler data = fewer scanning errors
5. **Security**: Only the pass ID is exposed in the QR code

## Scanner Compatibility

Both authority types now use the same scanner:
- **Local Authority**: Scans QR → validates pass → logs scan with purpose/notes
- **Border Control**: Scans QR → validates pass → determines check-in/check-out action → processes movement

The QR code is just the pass ID. All other data is fetched from the database after scanning.

## Verification

After running the SQL script, you should see:
- All passes have `qr_data` in format: `{"id": "uuid"}`
- QR codes scan quickly and reliably
- Both Local Authority and Border Control can scan the same passes

## Notes

- The app already handles this correctly
- The issue was only in the database storing complex data
- No app code changes needed
- Existing passes will be automatically updated by the SQL script
