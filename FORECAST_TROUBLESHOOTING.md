# Border Forecast Troubleshooting Guide

## Common Issues and Solutions

### 1. "Failed to fetch forecast data" Error

This error typically occurs when there are issues with the database query or data processing.

#### Possible Causes:
- No passes exist in the database for the selected border
- Date filtering is too restrictive
- Database connection issues
- Missing or invalid border ID

#### Solutions:

**Check if passes exist:**
```sql
SELECT COUNT(*) FROM purchased_passes 
WHERE entry_point_id = 'your-border-id' OR exit_point_id = 'your-border-id';
```

**Check pass dates:**
```sql
SELECT activation_date, expires_at, pass_description 
FROM purchased_passes 
WHERE entry_point_id = 'your-border-id' OR exit_point_id = 'your-border-id'
ORDER BY activation_date DESC
LIMIT 10;
```

**Verify border exists:**
```sql
SELECT id, name, is_active FROM borders WHERE id = 'your-border-id';
```

### 2. "No data available" in Forecast Tab

This happens when the forecast calculation returns empty results.

#### Possible Causes:
- No passes scheduled for the selected forecast period
- All passes are in the past (historical data)
- Incorrect date range selection

#### Solutions:

**Check for future passes:**
```sql
SELECT COUNT(*) FROM purchased_passes 
WHERE (entry_point_id = 'your-border-id' OR exit_point_id = 'your-border-id')
AND (activation_date > NOW() OR expires_at > NOW());
```

**Create test data:**
```sql
-- Insert a test pass for tomorrow
INSERT INTO purchased_passes (
  profile_id, authority_id, country_id, entry_point_id,
  pass_description, vehicle_description, entry_limit, entries_remaining,
  activation_date, expires_at, currency, amount
) VALUES (
  'your-profile-id', 'your-authority-id', 'your-country-id', 'your-border-id',
  'Tourist Pass', 'Car - Test Vehicle', 1, 1,
  NOW() + INTERVAL '1 day', NOW() + INTERVAL '8 days',
  'USD', 50.00
);
```

### 3. Vehicle Type Forecast Shows "N/A"

This occurs when vehicle descriptions don't match the expected patterns.

#### Current Vehicle Type Logic:
- **Car**: Contains "car" or "sedan"
- **Truck**: Contains "truck" or "lorry"  
- **Bus**: Contains "bus"
- **Motorcycle**: Contains "motorcycle" or "bike"
- **Van**: Contains "van"
- **Other**: Default for unmatched descriptions

#### Solutions:

**Check vehicle descriptions:**
```sql
SELECT DISTINCT vehicle_description FROM purchased_passes 
WHERE entry_point_id = 'your-border-id' OR exit_point_id = 'your-border-id';
```

**Update vehicle descriptions to match patterns:**
```sql
UPDATE purchased_passes 
SET vehicle_description = 'Car - ' || vehicle_description 
WHERE vehicle_description NOT LIKE '%car%' 
AND vehicle_description NOT LIKE '%truck%' 
AND vehicle_description NOT LIKE '%bus%';
```

### 4. Expected Revenue Shows $0

This happens when pass amounts are zero or null.

#### Solutions:

**Check pass amounts:**
```sql
SELECT amount, currency, pass_description FROM purchased_passes 
WHERE entry_point_id = 'your-border-id' OR exit_point_id = 'your-border-id'
AND amount > 0;
```

**Update zero amounts:**
```sql
UPDATE purchased_passes 
SET amount = 50.00 
WHERE amount = 0 OR amount IS NULL;
```

### 5. Date Filtering Issues

The forecast uses specific date logic for different periods.

#### Date Filter Logic:
- **Today**: Current day (00:00 to 23:59)
- **Tomorrow**: Next day (00:00 to 23:59)
- **Next Week**: Next Monday to Sunday
- **Next Month**: First day to last day of next month

#### Debug Date Ranges:
Add this to your test code to see the actual date ranges:
```dart
final dateRange = BorderForecastService._getDateRange('today', null, null);
print('Start: ${dateRange.start}');
print('End: ${dateRange.end}');
```

### 6. Database Schema Issues

Ensure your database schema matches the expected structure.

#### Required Tables:
- `purchased_passes` - Main pass data
- `borders` - Border information
- `authorities` - Authority data
- `countries` - Country data

#### Required Fields in purchased_passes:
- `id` (UUID)
- `entry_point_id` (UUID, references borders.id)
- `exit_point_id` (UUID, references borders.id)
- `activation_date` (timestamp)
- `expires_at` (timestamp)
- `amount` (numeric)
- `currency` (text)
- `vehicle_description` (text)
- `pass_description` (text)

### 7. Permission Issues

Ensure the user has proper access to the border data.

#### Check User Permissions:
```sql
-- Check if user has border manager role
SELECT pr.*, r.name as role_name 
FROM profile_roles pr 
JOIN roles r ON pr.role_id = r.id 
WHERE pr.profile_id = 'your-profile-id' 
AND r.name IN ('border_manager', 'country_admin');

-- Check border assignments
SELECT bmb.*, b.name as border_name 
FROM border_manager_borders bmb 
JOIN borders b ON bmb.border_id = b.id 
WHERE bmb.profile_id = 'your-profile-id' 
AND bmb.is_active = true;
```

## Testing Steps

### 1. Use the Test Utility

Use the `TestForecastData` widget to test forecast functionality:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TestForecastData(borderId: 'your-border-id'),
  ),
);
```

### 2. Check Console Output

Look for debug messages in the console:
- `🔍 Fetching forecast data for border: ...`
- `📅 Date range: ... to ...`
- `📊 Total passes found: ...`
- `📊 Filtered passes for forecast: ...`
- `🚗 Expected check-ins: ..., check-outs: ...`
- `✅ Forecast data generated successfully`

### 3. Verify Data Flow

1. **Border Selection**: Ensure a border is selected
2. **Date Filter**: Check that the date filter is appropriate
3. **Data Retrieval**: Verify passes are being retrieved from database
4. **Data Processing**: Confirm calculations are working
5. **UI Display**: Check that data is displayed correctly

## Sample Data Creation

If you need to create sample data for testing:

```sql
-- Create a test border (if needed)
INSERT INTO borders (id, country_id, authority_id, name, is_active) 
VALUES (
  gen_random_uuid(), 
  'your-country-id', 
  'your-authority-id', 
  'Test Border', 
  true
);

-- Create sample passes for different dates
INSERT INTO purchased_passes (
  profile_id, authority_id, country_id, entry_point_id,
  pass_description, vehicle_description, entry_limit, entries_remaining,
  activation_date, expires_at, currency, amount
) VALUES 
-- Today's passes
('profile-1', 'authority-id', 'country-id', 'border-id',
 'Tourist Pass', 'Car - Honda Civic', 1, 1,
 CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 'USD', 50.00),

-- Tomorrow's passes  
('profile-2', 'authority-id', 'country-id', 'border-id',
 'Business Pass', 'Truck - Ford F150', 1, 1,
 CURRENT_DATE + INTERVAL '1 day', CURRENT_DATE + INTERVAL '8 days', 'USD', 75.00),

-- Next week's passes
('profile-3', 'authority-id', 'country-id', 'border-id',
 'Commercial Pass', 'Bus - Mercedes', 1, 1,
 CURRENT_DATE + INTERVAL '7 days', CURRENT_DATE + INTERVAL '14 days', 'USD', 100.00);
```

## Performance Considerations

### 1. Large Datasets

For borders with many passes, consider:
- Adding database indexes on date fields
- Implementing pagination
- Caching forecast results

### 2. Query Optimization

```sql
-- Add indexes for better performance
CREATE INDEX idx_purchased_passes_entry_point_activation 
ON purchased_passes(entry_point_id, activation_date);

CREATE INDEX idx_purchased_passes_exit_point_expires 
ON purchased_passes(exit_point_id, expires_at);
```

### 3. Caching Strategy

Consider implementing caching for frequently accessed forecasts:
- Cache results for common date ranges
- Invalidate cache when new passes are created
- Use appropriate cache expiration times

## Getting Help

If you continue to experience issues:

1. **Check the console logs** for detailed error messages
2. **Verify your database schema** matches the expected structure
3. **Test with sample data** to isolate the issue
4. **Use the test utility** to debug specific functionality
5. **Check user permissions** and border assignments

The forecast functionality is designed to be robust and handle edge cases, but proper data setup and permissions are essential for it to work correctly.