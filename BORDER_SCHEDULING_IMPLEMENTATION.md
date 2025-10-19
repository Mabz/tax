# Border Officials Scheduling System - Implementation Guide

## 🎯 Overview

The Border Officials Scheduling System enables accurate performance metrics by tracking scheduled vs actual work hours for border officials. This system provides template-based scheduling with historical snapshots for data integrity.

## 📋 Features Implemented

### ✅ Phase 1: Foundation (Completed)
- **Database Models**: Complete data models for schedules, time slots, assignments, and snapshots
- **Service Layer**: Comprehensive service for managing all scheduling operations
- **Basic UI**: Schedule management screen with template creation and configuration
- **Access Control**: Role-based permissions for Border Managers and Country Administrators

### 🔄 Phase 2: Core Functionality (Next Steps)
- Official assignment interface with drag-and-drop
- Conflict detection and validation
- Enhanced schedule visualization
- Bulk assignment tools

### 📊 Phase 3: Advanced Features (Future)
- Schedule analytics and insights
- Performance correlation with schedules
- Automated schedule optimization
- Mobile schedule access for officials

## 🏗️ Architecture

### Database Schema
```
border_schedule_templates
├── id (UUID, Primary Key)
├── border_id (UUID, Foreign Key → borders)
├── template_name (VARCHAR)
├── description (TEXT, Optional)
├── is_active (BOOLEAN)
├── created_by (UUID, Foreign Key → profiles)
├── created_at (TIMESTAMP)
├── updated_at (TIMESTAMP)
└── UNIQUE INDEX: Only one active template per border

schedule_time_slots
├── id (UUID, Primary Key)
├── template_id (UUID, Foreign Key → border_schedule_templates)
├── day_of_week (INTEGER, 1-7)
├── start_time (TIME)
├── end_time (TIME)
├── min_officials (INTEGER)
├── max_officials (INTEGER)
└── is_active (BOOLEAN)

official_schedule_assignments
├── id (UUID, Primary Key)
├── time_slot_id (UUID, Foreign Key → schedule_time_slots)
├── profile_id (UUID, Foreign Key → profiles)
├── effective_from (DATE)
├── effective_to (DATE, Optional)
├── assignment_type (VARCHAR: primary/backup/temporary)
├── created_by (UUID, Foreign Key → profiles)
├── created_at (TIMESTAMP)
└── Conflict detection handled at application level

schedule_snapshots
├── id (UUID, Primary Key)
├── template_id (UUID, Foreign Key → border_schedule_templates)
├── snapshot_date (DATE)
├── snapshot_data (JSONB)
├── reason (VARCHAR)
├── created_by (UUID, Foreign Key → profiles)
└── created_at (TIMESTAMP)
```

### Key Components

#### Models (`lib/models/`)
- `BorderScheduleTemplate`: Reusable schedule templates
- `ScheduleTimeSlot`: Time slots within templates
- `OfficialScheduleAssignment`: Official assignments to time slots
- `ScheduleSnapshot`: Historical schedule configurations

#### Services (`lib/services/`)
- `BorderScheduleService`: Complete CRUD operations for all scheduling entities

#### Screens (`lib/screens/`)
- `BorderScheduleManagementScreen`: Main scheduling interface

#### Widgets (`lib/widgets/`)
- `ScheduleTemplateBuilderWidget`: Visual schedule configuration tool

## 🚀 Getting Started

### 1. Database Setup
Choose one of the schema files based on your needs:

**Option A: Full Schema** (`database_schema_border_scheduling.sql`)
- Complete schema with triggers and utility functions
- Automatic snapshot creation
- Advanced conflict detection functions

**Option B: Simplified Schema** (`database_schema_border_scheduling_simple.sql`)
- Basic schema without complex functions
- Easier deployment and compatibility
- Application-level conflict detection

```sql
-- Run your chosen schema file to create:
-- - All tables with proper constraints
-- - Row Level Security policies
-- - Performance indexes
-- - (Optional) Triggers and utility functions
```

### 2. Access the System
1. Navigate to **Border Management** menu
2. Select **Border Schedules**
3. Choose a border from the dropdown
4. Create your first schedule template

### 3. Configure Schedules
1. **Create Template**: Name and describe your schedule
2. **Add Time Slots**: Configure daily time slots with official requirements
3. **Assign Officials**: (Coming in Phase 2)

## 🔐 Security & Permissions

### Role-Based Access Control
- **Border Managers**: Can manage schedules for their assigned borders
- **Country Administrators**: Can manage all schedules within their country
- **Border Officials**: Can view their own assignments (read-only)

### Row Level Security (RLS)
All tables implement RLS policies ensuring users can only access data they're authorized to see.

## 📊 Data Integrity Features

### Automatic Snapshots
The system automatically creates snapshots when:
- Schedule templates are activated/deactivated
- Time slots are modified
- Official assignments change
- Monthly archives are created

### Validation & Constraints
- Only one active template per border (enforced by unique index)
- Time slot validation (start ≠ end time)
- Official capacity constraints (min ≤ max)
- Date range validation for assignments
- Assignment conflict detection (prevents overlapping schedules for same official)

## 🎨 User Interface

### Schedule Management Screen
- **Border Selection**: Dropdown to choose border
- **Template List**: View all templates with status indicators
- **Template Actions**: Create, edit, delete, activate/deactivate

### Schedule Template Builder
- **Visual Time Grid**: 7-day weekly view
- **Time Slot Management**: Add, edit, delete time slots
- **Statistics**: Total slots, hours, coverage percentage
- **Validation**: Real-time conflict detection

## 🔧 Technical Implementation

### Key Features
1. **Template-Based Approach**: Reusable schedule configurations
2. **Historical Tracking**: Complete audit trail with snapshots
3. **Flexible Time Slots**: Support for any time range and official count
4. **Conflict Detection**: Prevent overlapping assignments
5. **Performance Integration**: Ready for analytics correlation

### Error Handling
- Comprehensive try-catch blocks
- User-friendly error messages
- Graceful fallbacks for missing data
- Loading states and retry mechanisms

## 📈 Future Enhancements

### Phase 2: Official Assignment
- Drag-and-drop assignment interface
- Official availability checking
- Bulk assignment operations
- Assignment conflict resolution

### Phase 3: Analytics Integration
- Scheduled vs actual performance metrics
- Schedule adherence tracking
- Optimal staffing recommendations
- Performance correlation analysis

### Phase 4: Advanced Features
- Mobile app for officials
- Automated schedule generation
- Integration with HR systems
- Real-time schedule updates

## 🐛 Troubleshooting

### Database Setup Issues
1. **PostgreSQL function errors**: Use the simplified schema (`database_schema_border_scheduling_simple.sql`)
2. **IMMUTABLE function errors**: The simplified schema avoids complex functions
3. **Constraint violations**: Check unique indexes and constraint definitions
4. **Missing table errors**: Schema now uses correct table names (`border_manager_borders` instead of `border_managers`)
5. **Role system compatibility**: RLS policies updated to work with `profile_roles` table structure

### Common Issues
1. **No borders available**: Check user permissions and border assignments
2. **Template creation fails**: Verify database permissions and constraints
3. **Time slot conflicts**: Use the built-in validation functions
4. **Active template constraint**: Only one template per border can be active

### Debug Information
The system includes comprehensive logging:
- Service operations with debug prints
- Error details with stack traces
- User action tracking
- Conflict detection details

## 📝 API Reference

### BorderScheduleService Methods

#### Template Management
```dart
// Get templates for a border
Future<List<BorderScheduleTemplate>> getScheduleTemplatesForBorder(String borderId)

// Create new template
Future<BorderScheduleTemplate> createScheduleTemplate({
  required String borderId,
  required String templateName,
  String? description,
  bool isActive = true,
})

// Update template
Future<BorderScheduleTemplate> updateScheduleTemplate(String templateId, {...})

// Delete template
Future<void> deleteScheduleTemplate(String templateId)
```

#### Time Slot Management
```dart
// Get time slots for template
Future<List<ScheduleTimeSlot>> getTimeSlots(String templateId)

// Create time slot
Future<ScheduleTimeSlot> createTimeSlot({
  required String templateId,
  required int dayOfWeek,
  required String startTime,
  required String endTime,
  int minOfficials = 1,
  int maxOfficials = 3,
})
```

#### Assignment Management
```dart
// Get assignments for time slot
Future<List<OfficialScheduleAssignment>> getAssignmentsForTimeSlot(String timeSlotId)

// Assign official to time slot
Future<OfficialScheduleAssignment> assignOfficialToTimeSlot({
  required String timeSlotId,
  required String profileId,
  required DateTime effectiveFrom,
  DateTime? effectiveTo,
  String assignmentType = 'primary',
})
```

## 🎉 Success Metrics

This implementation provides:
- **Accurate Performance Tracking**: Officials are only measured during scheduled hours
- **Historical Data Integrity**: Complete audit trail of all schedule changes
- **Flexible Configuration**: Supports any border's unique scheduling needs
- **Scalable Architecture**: Ready for future enhancements and integrations

The system is now ready for Phase 2 implementation, which will add the official assignment interface and enhanced analytics integration.