# Border Movement Implementation

## Overview
Added a new "Movement" view to Border Analytics that provides a vehicle-centric perspective of border movements, focusing on check-ins and check-outs from the `pass_movements` table with relationships to `purchased_passes` for vehicle information.

## Features Implemented

### 1. Movement List View
- **File**: `lib/screens/border_movement_screen.dart`
- Lists all movements for a specific border (check-in, check-out, local authority scans)
- Shows movement type, vehicle information, timestamp, and official details
- Real-time data from `pass_movements` table

### 2. Vehicle Search Functionality
- **Service**: `lib/services/border_movement_service.dart`
- Search by vehicle VIN, make, model, or registration number
- Groups movements by vehicle to show summary information
- Displays total movements and last movement type per vehicle

### 3. Pass Movement History Dialog
- **Widget**: `lib/widgets/pass_movement_history_dialog.dart`
- Shows complete movement history for a selected vehicle
- Chronological timeline of all movements
- Detailed information including officials, timestamps, and notes

### 4. Data Models
- **Model**: `lib/models/pass_movement.dart`
- `PassMovement` class for individual movement records
- `VehicleMovementSummary` class for aggregated vehicle data
- Proper JSON serialization and display formatting

## Database Integration

### Tables Used
- `pass_movements` - Core movement data (check-in/check-out events)
- `purchased_passes` - Vehicle and owner information
- `borders` - Border location details
- `border_officials` - Official information
- `profiles` - User profile data for officials and owners

### Database Function
- **File**: `database_functions/search_border_vehicles.sql`
- `search_border_vehicles()` function for efficient vehicle searching
- Aggregates movements by vehicle with search capabilities
- Handles VIN, registration number, make, model searches

## Integration with Border Analytics

### New Tab Added
- Added "Movement" as the 4th tab in `BorderAnalyticsScreen`
- Integrated seamlessly with existing analytics tabs
- Maintains consistent UI/UX with other analytics views

### Navigation Flow
1. **Border Analytics** → **Movement Tab**
2. **Movement List** → Shows recent movements for selected border
3. **Vehicle Search** → Search and filter vehicles
4. **Vehicle Selection** → Click vehicle to see complete movement history
5. **Movement History** → Detailed timeline with Pass Movement History dialog

## Key Components

### BorderMovementScreen
- Main screen for movement view
- Handles both movement list and vehicle search
- Responsive search with real-time filtering
- Error handling and loading states

### BorderMovementService
- API service for movement data
- Handles Supabase queries with proper joins
- Fallback search implementation for compatibility
- Vehicle grouping and aggregation logic

### PassMovementHistoryDialog
- Modal dialog showing complete vehicle history
- Timeline-style layout with movement details
- Color-coded movement types (check-in/check-out/scan)
- Current status highlighting

## Search Capabilities

### Vehicle Search Fields
- **VIN**: Vehicle Identification Number
- **Make**: Vehicle manufacturer (Toyota, Ford, etc.)
- **Model**: Vehicle model (Camry, F-150, etc.)
- **Registration Number**: License plate number

### Search Features
- Real-time search as you type (minimum 2 characters)
- Case-insensitive matching
- Partial string matching
- Results grouped by unique vehicle
- Shows movement count and last activity

## UI/UX Features

### Visual Design
- Consistent with Border Analytics theme (purple color scheme)
- Card-based layout for movements and vehicles
- Color-coded movement types:
  - **Green**: Check-in (vehicle entering)
  - **Orange**: Check-out (vehicle leaving)
  - **Blue**: Local authority scan
- Timeline-style movement history

### User Experience
- Search-first approach for finding specific vehicles
- Clear movement type indicators and timestamps
- Detailed vehicle information display
- Easy navigation between list and detail views

## Testing

### Test File
- **File**: `test_border_movement_screen.dart`
- Demonstrates all movement features
- Shows integration with Border Analytics
- Provides test navigation to movement screen

## Future Enhancements

### Potential Improvements
1. **Map Integration**: Show movement locations on map
2. **Export Functionality**: Export movement data to CSV/PDF
3. **Advanced Filters**: Date range, movement type filters
4. **Real-time Updates**: Live movement tracking
5. **Analytics**: Movement patterns and statistics
6. **Notifications**: Alerts for specific vehicle movements

### Performance Optimizations
1. **Pagination**: Load movements in batches
2. **Caching**: Cache frequently accessed vehicle data
3. **Indexing**: Database indexes for search performance
4. **Lazy Loading**: Load movement details on demand

## Database Schema Requirements

### Required Tables
```sql
-- pass_movements table should have:
- id (UUID, primary key)
- pass_id (UUID, foreign key to purchased_passes)
- border_id (UUID, foreign key to borders)
- official_id (UUID, foreign key to border_officials)
- movement_type (TEXT: 'check_in', 'check_out', 'local_authority_scan')
- timestamp (TIMESTAMP WITH TIME ZONE)
- latitude (DECIMAL)
- longitude (DECIMAL)
- notes (TEXT)

-- purchased_passes table should have vehicle fields:
- vehicle_registration_number (TEXT)
- vehicle_vin (TEXT)
- vehicle_make (TEXT)
- vehicle_model (TEXT)
- vehicle_year (INTEGER)
- vehicle_color (TEXT)
- vehicle_description (TEXT)
```

## Implementation Notes

### Error Handling
- Graceful fallback when database function doesn't exist
- Proper error messages for network issues
- Loading states for better user experience

### Performance Considerations
- Efficient queries with proper joins
- Limited result sets to prevent performance issues
- Indexed search fields for fast vehicle lookup

### Security
- Proper authentication checks
- Border-specific data filtering
- No sensitive data exposure in search results

This implementation provides a comprehensive vehicle movement tracking system that integrates seamlessly with the existing Border Analytics platform while offering powerful search and visualization capabilities.