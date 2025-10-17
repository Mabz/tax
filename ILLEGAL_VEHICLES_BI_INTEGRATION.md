# Illegal Vehicles BI Integration

## 🎯 **Overview**
Added "Illegal Vehicles In-Country" detection to the Non-Compliance Analytics screen. This identifies vehicles that were scanned by local authorities but show as "Departed", indicating potential border control bypass or illegal re-entry.

## 🚨 **What This Detects**
- **Vehicles found in-country but showing as "Departed"**
- **Potential border control bypass** - vehicles that entered without proper check-in
- **Illegal re-entry** - vehicles that left but returned without going through border control
- **System integrity issues** - data inconsistencies requiring investigation

## 📊 **Implementation Details**

### **1. Non-Compliance Screen Updates**
**File**: `lib/screens/bi/non_compliance_screen.dart`

- **Added new analytics card** below Overstayed Vehicles
- **Updated non-compliance banner** to include illegal vehicles count
- **Added detailed popup** showing illegal vehicles list with risk levels
- **Integrated with existing filter system**

### **2. Business Intelligence Service**
**File**: `lib/services/business_intelligence_service.dart`

- **Added `_getIllegalVehiclesData()` method** to fetch illegal vehicles data
- **Updated `getNonComplianceAnalytics()`** to include illegal vehicles metrics
- **Added error handling** to prevent UI breaking if data unavailable

### **3. Database Function**
**File**: `create_illegal_vehicles_function.sql`

- **Created `get_illegal_vehicles_in_country()` function**
- **Identifies vehicles scanned by local authority but showing as departed**
- **Includes risk level calculation** (HIGH/MEDIUM/LOW based on recency)
- **Provides comprehensive vehicle details** for investigation

## 🔍 **Detection Logic**

```sql
-- Core detection criteria:
WHERE 
  pm.movement_type = 'local_authority_scan'  -- Found by local authority
  AND pp.vehicle_status_display = 'Departed' -- But shows as departed
  AND pm.processed_at >= NOW() - INTERVAL '30 days' -- Recent scans
```

## 📈 **BI Value**

### **Security Analytics**
- Track patterns of illegal entries
- Identify high-risk vehicles and owners
- Monitor border control effectiveness

### **Compliance Monitoring**
- Real-time violation detection
- Risk-based prioritization
- Audit trail for investigations

### **Operational Insights**
- Border security gap analysis
- Resource allocation optimization
- Trend analysis over time

## 🎨 **UI Features**

### **Analytics Card**
- **Orange warning theme** indicating security concern
- **Click-to-expand** detailed view
- **Risk level indicators** (HIGH/MEDIUM/LOW)
- **Integration with existing filters**

### **Detailed Popup**
- **Vehicle information** with owner details
- **Last scan location and date**
- **Days since departure** calculation
- **Risk level badges** for quick assessment
- **Future expansion** ready for detailed screen

## 🚀 **Next Steps**

### **Immediate**
1. **Apply the SQL function** to your database
2. **Test with sample data** to verify detection
3. **Monitor for false positives** and adjust logic if needed

### **Future Enhancements**
1. **Dedicated illegal vehicles screen** with advanced filtering
2. **Real-time alerts** for high-risk detections
3. **Integration with border control systems** for automatic flagging
4. **Machine learning** for pattern recognition and fraud detection

## 📋 **Setup Instructions**

1. **Run the SQL function**:
   ```bash
   psql -d your_database -f create_illegal_vehicles_function.sql
   ```

2. **Test the function**:
   ```sql
   SELECT * FROM get_illegal_vehicles_in_country('your-authority-id', 30);
   ```

3. **Verify UI integration** in Non-Compliance Analytics screen

## 🔧 **Configuration**

- **Default lookback period**: 30 days (configurable)
- **Risk levels**: Based on scan recency
- **Filters**: Inherits from existing non-compliance filters
- **Permissions**: Requires authenticated user access

This integration provides critical security insights while maintaining the existing UI patterns and user experience.