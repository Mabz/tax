# Vehicle Data Source Confirmation

## Data Source Verification
✅ **CONFIRMED**: Vehicle information in the audit trail is correctly sourced from the `purchased_passes` table, which provides a snapshot of vehicle details at the time the pass was purchased.

## Why This Is Important

### **Snapshot vs. Live Data**
- **Snapshot Data** (purchased_passes): Vehicle details as they were when the pass was purchased
- **Live Data** (vehicles table): Current vehicle details that may have changed since purchase

### **Audit Trail Requirements**
For audit purposes, we need **snapshot data** because:
1. **Historical Accuracy**: Shows vehicle details as they were at the time of the activity
2. **Audit Integrity**: Prevents retroactive changes from affecting historical records
3. **Legal Compliance**: Provides accurate evidence for investigations
4. **Data Consistency**: Ensures audit trail reflects the actual state during the activity

## Current Implementation

### **Database Query**
```sql
SELECT 
  id,
  pass_id,
  movement_type,
  entries_deducted,
  ...
  purchased_passes!inner(
    id,
    vehicle_description,
    vehicle_registration_number,  -- ✅ From purchased_passes
    vehicle_make,                 -- ✅ From purchased_passes  
    vehicle_model,                -- ✅ From purchased_passes
    status,
    ...
  )
FROM pass_movements
```

### **Data Mapping**
```dart
vehicleDescription: record['purchased_passes']?['vehicle_description'] as String?,
vehicleRegistration: record['purchased_passes']?['vehicle_registration_number'] as String?,
vehicleMake: record['purchased_passes']?['vehicle_make'] as String?,
vehicleModel: record['purchased_passes']?['vehicle_model'] as String?,
```

## Benefits of Using purchased_passes Table

### **1. Historical Accuracy**
- Vehicle details reflect the state when the pass was active
- No confusion from vehicle updates after pass purchase
- Accurate audit trail for compliance and legal purposes

### **2. Data Integrity**
- Immutable snapshot prevents data corruption in audit records
- Consistent reporting regardless of current vehicle status
- Reliable evidence for investigations and disputes

### **3. Performance**
- No additional joins to vehicles table required
- Faster queries with direct access to snapshot data
- Reduced database load for audit operations

### **4. Compliance**
- Meets regulatory requirements for audit trail accuracy
- Supports legal proceedings with accurate historical data
- Provides complete context for each activity

## Example Scenarios

### **Scenario 1: Vehicle Sold After Pass Purchase**
```
Pass purchased: 2025-01-01
Vehicle: ABC123GP • Toyota Corolla
Vehicle sold: 2025-01-15 (new owner changes details)
Audit activity: 2025-01-20

✅ Audit shows: ABC123GP • Toyota Corolla (correct snapshot)
❌ If using live data: XYZ789GP • Honda Civic (incorrect current data)
```

### **Scenario 2: Registration Number Changed**
```
Pass purchased: 2025-01-01  
Vehicle: OLD123GP • Ford Focus
Registration changed: 2025-01-10 → NEW456GP
Audit activity: 2025-01-15

✅ Audit shows: OLD123GP • Ford Focus (correct at time of activity)
❌ If using live data: NEW456GP • Ford Focus (misleading)
```

### **Scenario 3: Investigation Requirements**
```
Incident date: 2025-01-05
Pass used: Vehicle ABC123GP • Toyota Corolla
Investigation date: 2025-02-01 (vehicle details may have changed)

✅ Audit provides: Accurate vehicle details from incident date
✅ Legal evidence: Reliable snapshot data for court proceedings
✅ Compliance: Meets regulatory audit trail requirements
```

## Technical Implementation Notes

- Vehicle data is stored in `purchased_passes` table when pass is created
- Data includes: description, registration_number, make, model, VIN, etc.
- Audit trail queries this snapshot data directly
- No real-time lookups to vehicles table needed
- Maintains data consistency across all audit operations

This approach ensures the audit trail provides accurate, reliable, and legally compliant vehicle information for all border control activities.