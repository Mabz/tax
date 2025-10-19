import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';

/// Border Managers Analytics Data Model
class BorderManagersAnalyticsData {
  // Vehicle Flow Metrics
  final int expectedCheckIns;
  final int expectedCheckOuts;
  final int actualCheckIns;
  final int actualCheckOuts;
  final int missedCheckIns;
  final int missedCheckOuts;

  // Vehicle Types
  final Map<String, VehicleTypeAnalytics> vehicleTypeBreakdown;
  final String topVehicleType;

  // Pass Analytics
  final int activePasses;
  final int expiredPasses;
  final int upcomingPasses;
  final List<PassAnalytics> passBreakdown;

  // Revenue Analytics
  final double expectedRevenue;
  final double actualRevenue;
  final double missedRevenue;
  final List<RevenueByDay> dailyRevenue;

  // Time-based Analytics
  final String peakTrafficTime;
  final Map<String, int> hourlyDistribution;
  final List<TrafficFlowData> trafficFlow;

  // Comparison Data
  final double revenueGrowth;
  final double passVolumeGrowth;
  final double checkInGrowth;
  final double checkOutGrowth;

  BorderManagersAnalyticsData({
    required this.expectedCheckIns,
    required this.expectedCheckOuts,
    required this.actualCheckIns,
    required this.actualCheckOuts,
    required this.missedCheckIns,
    required this.missedCheckOuts,
    required this.vehicleTypeBreakdown,
    required this.topVehicleType,
    required this.activePasses,
    required this.expiredPasses,
    required this.upcomingPasses,
    required this.passBreakdown,
    required this.expectedRevenue,
    required this.actualRevenue,
    required this.missedRevenue,
    required this.dailyRevenue,
    required this.peakTrafficTime,
    required this.hourlyDistribution,
    required this.trafficFlow,
    required this.revenueGrowth,
    required this.passVolumeGrowth,
    required this.checkInGrowth,
    required this.checkOutGrowth,
  });
}

/// Vehicle Type Analytics Model
class VehicleTypeAnalytics {
  final String vehicleType;
  final int expectedCheckIns;
  final int expectedCheckOuts;
  final int actualCheckIns;
  final int actualCheckOuts;
  final int missedScans;
  final double revenue;
  final double averagePassValue;

  VehicleTypeAnalytics({
    required this.vehicleType,
    required this.expectedCheckIns,
    required this.expectedCheckOuts,
    required this.actualCheckIns,
    required this.actualCheckOuts,
    required this.missedScans,
    required this.revenue,
    required this.averagePassValue,
  });
}

/// Pass Analytics Model
class PassAnalytics {
  final String passType;
  final int count;
  final double totalValue;
  final int expectedCheckIns;
  final int expectedCheckOuts;
  final int missedScans;
  final DateTime startDate;
  final DateTime endDate;

  PassAnalytics({
    required this.passType,
    required this.count,
    required this.totalValue,
    required this.expectedCheckIns,
    required this.expectedCheckOuts,
    required this.missedScans,
    required this.startDate,
    required this.endDate,
  });
}

/// Revenue by Day Model
class RevenueByDay {
  final DateTime date;
  final double expectedRevenue;
  final double actualRevenue;
  final int passCount;
  final int checkIns;
  final int checkOuts;

  RevenueByDay({
    required this.date,
    required this.expectedRevenue,
    required this.actualRevenue,
    required this.passCount,
    required this.checkIns,
    required this.checkOuts,
  });
}

/// Traffic Flow Data Model
class TrafficFlowData {
  final DateTime timestamp;
  final int checkIns;
  final int checkOuts;
  final int netFlow; // checkIns - checkOuts
  final String peakHour;

  TrafficFlowData({
    required this.timestamp,
    required this.checkIns,
    required this.checkOuts,
    required this.netFlow,
    required this.peakHour,
  });
}

/// Border Managers Analytics Service
class BorderManagersAnalyticsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get comprehensive analytics data for a border
  static Future<BorderManagersAnalyticsData> getAnalyticsData(
    String borderId,
    String dateFilter, {
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    try {
      debugPrint(
          '🔍 Fetching border managers analytics for border: $borderId, filter: $dateFilter');

      final dateRange =
          _getDateRange(dateFilter, customStartDate, customEndDate);

      // Get all passes for the border within the date range
      final passesResponse = await _supabase
          .from('purchased_passes')
          .select('''
            *,
            pass_templates!inner(
              id,
              name,
              description,
              vehicle_type_id,
              vehicle_types(name)
            )
          ''')
          .or('entry_point_id.eq.$borderId,exit_point_id.eq.$borderId')
          .gte('start_date', dateRange.start.toIso8601String())
          .lte('start_date', dateRange.end.toIso8601String())
          .order('start_date');

      final passes =
          passesResponse.map((json) => PurchasedPass.fromJson(json)).toList();

      // Calculate vehicle flow metrics
      final vehicleFlowMetrics =
          _calculateVehicleFlowMetrics(passes, dateRange);

      // Calculate vehicle type breakdown
      final vehicleTypeBreakdown = _calculateVehicleTypeBreakdown(passes);
      final topVehicleType = _getTopVehicleType(vehicleTypeBreakdown);

      // Calculate pass analytics
      final passAnalytics = _calculatePassAnalytics(passes, dateRange);

      // Calculate revenue analytics
      final revenueAnalytics = _calculateRevenueAnalytics(passes, dateRange);

      // Calculate time-based analytics
      final timeAnalytics = _calculateTimeBasedAnalytics(passes, dateRange);

      return BorderManagersAnalyticsData(
        expectedCheckIns: vehicleFlowMetrics['expectedCheckIns'] ?? 0,
        expectedCheckOuts: vehicleFlowMetrics['expectedCheckOuts'] ?? 0,
        actualCheckIns: vehicleFlowMetrics['actualCheckIns'] ?? 0,
        actualCheckOuts: vehicleFlowMetrics['actualCheckOuts'] ?? 0,
        missedCheckIns: vehicleFlowMetrics['missedCheckIns'] ?? 0,
        missedCheckOuts: vehicleFlowMetrics['missedCheckOuts'] ?? 0,
        vehicleTypeBreakdown: vehicleTypeBreakdown,
        topVehicleType: topVehicleType,
        activePasses: passAnalytics['activePasses'] ?? 0,
        expiredPasses: passAnalytics['expiredPasses'] ?? 0,
        upcomingPasses: passAnalytics['upcomingPasses'] ?? 0,
        passBreakdown: passAnalytics['breakdown'] ?? [],
        expectedRevenue: revenueAnalytics['expectedRevenue'] ?? 0.0,
        actualRevenue: revenueAnalytics['actualRevenue'] ?? 0.0,
        missedRevenue: revenueAnalytics['missedRevenue'] ?? 0.0,
        dailyRevenue: revenueAnalytics['dailyRevenue'] ?? [],
        peakTrafficTime: timeAnalytics['peakTrafficTime'] ?? 'N/A',
        hourlyDistribution: timeAnalytics['hourlyDistribution'] ?? {},
        trafficFlow: timeAnalytics['trafficFlow'] ?? [],
        revenueGrowth: 0.0, // Will be calculated in comparison
        passVolumeGrowth: 0.0,
        checkInGrowth: 0.0,
        checkOutGrowth: 0.0,
      );
    } catch (e) {
      debugPrint('❌ Error fetching border managers analytics: $e');
      throw Exception('Failed to fetch analytics data: $e');
    }
  }

  /// Get comparison data for analytics
  static Future<BorderManagersAnalyticsData> getComparisonData(
    String borderId,
    String dateFilter,
    String comparisonType, {
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    try {
      final currentDateRange =
          _getDateRange(dateFilter, customStartDate, customEndDate);
      final comparisonDateRange = _getComparisonDateRange(
        currentDateRange,
        comparisonType,
      );

      return await getAnalyticsData(
        borderId,
        'custom',
        customStartDate: comparisonDateRange.start,
        customEndDate: comparisonDateRange.end,
      );
    } catch (e) {
      debugPrint('❌ Error fetching comparison data: $e');
      throw Exception('Failed to fetch comparison data: $e');
    }
  }

  /// Calculate vehicle flow metrics
  static Map<String, int> _calculateVehicleFlowMetrics(
    List<PurchasedPass> passes,
    AnalyticsDateRange dateRange,
  ) {
    int expectedCheckIns = 0;
    int expectedCheckOuts = 0;
    int actualCheckIns = 0;
    int actualCheckOuts = 0;

    for (final pass in passes) {
      // Expected check-ins: passes that start within the date range
      if (pass.activationDate.isAfter(dateRange.start) &&
          pass.activationDate
              .isBefore(dateRange.end.add(const Duration(days: 1)))) {
        expectedCheckIns++;
      }

      // Expected check-outs: passes that end within the date range
      if (pass.expiresAt.isAfter(dateRange.start) &&
          pass.expiresAt.isBefore(dateRange.end.add(const Duration(days: 1)))) {
        expectedCheckOuts++;
      }

      // Actual check-ins and check-outs would come from scan records
      // For now, we'll simulate based on pass status
      if (pass.currentStatus == 'checked_in') {
        actualCheckIns++;
      }
      if (pass.currentStatus == 'checked_out') {
        actualCheckOuts++;
      }
    }

    final missedCheckIns = expectedCheckIns - actualCheckIns;
    final missedCheckOuts = expectedCheckOuts - actualCheckOuts;

    return {
      'expectedCheckIns': expectedCheckIns,
      'expectedCheckOuts': expectedCheckOuts,
      'actualCheckIns': actualCheckIns,
      'actualCheckOuts': actualCheckOuts,
      'missedCheckIns': missedCheckIns > 0 ? missedCheckIns : 0,
      'missedCheckOuts': missedCheckOuts > 0 ? missedCheckOuts : 0,
    };
  }

  /// Calculate vehicle type breakdown
  static Map<String, VehicleTypeAnalytics> _calculateVehicleTypeBreakdown(
    List<PurchasedPass> passes,
  ) {
    final Map<String, List<PurchasedPass>> groupedByType = {};

    for (final pass in passes) {
      final vehicleType = _getVehicleTypeFromPass(pass);
      groupedByType.putIfAbsent(vehicleType, () => []).add(pass);
    }

    final Map<String, VehicleTypeAnalytics> breakdown = {};

    for (final entry in groupedByType.entries) {
      final vehicleType = entry.key;
      final typePasses = entry.value;

      final expectedCheckIns = typePasses.length;
      final expectedCheckOuts = typePasses.length;
      final actualCheckIns =
          typePasses.where((p) => p.currentStatus == 'checked_in').length;
      final actualCheckOuts =
          typePasses.where((p) => p.currentStatus == 'checked_out').length;
      final missedScans = (expectedCheckIns - actualCheckIns) +
          (expectedCheckOuts - actualCheckOuts);
      final revenue = typePasses.fold<double>(0.0, (sum, p) => sum + p.amount);
      final averagePassValue =
          typePasses.isNotEmpty ? revenue / typePasses.length : 0.0;

      breakdown[vehicleType] = VehicleTypeAnalytics(
        vehicleType: vehicleType,
        expectedCheckIns: expectedCheckIns,
        expectedCheckOuts: expectedCheckOuts,
        actualCheckIns: actualCheckIns,
        actualCheckOuts: actualCheckOuts,
        missedScans: missedScans > 0 ? missedScans : 0,
        revenue: revenue,
        averagePassValue: averagePassValue,
      );
    }

    return breakdown;
  }

  /// Calculate pass analytics
  static Map<String, dynamic> _calculatePassAnalytics(
    List<PurchasedPass> passes,
    AnalyticsDateRange dateRange,
  ) {
    final now = DateTime.now();

    final activePasses = passes
        .where((p) =>
            p.activationDate.isBefore(now) &&
            p.expiresAt.isAfter(now) &&
            p.status == 'active')
        .length;

    final expiredPasses = passes.where((p) => p.expiresAt.isBefore(now)).length;

    final upcomingPasses =
        passes.where((p) => p.activationDate.isAfter(now)).length;

    // Group passes by type for breakdown
    final Map<String, List<PurchasedPass>> groupedByType = {};
    for (final pass in passes) {
      final passType = _getPassTypeFromDescription(pass.passDescription);
      groupedByType.putIfAbsent(passType, () => []).add(pass);
    }

    final List<PassAnalytics> breakdown = [];
    for (final entry in groupedByType.entries) {
      final passType = entry.key;
      final typePasses = entry.value;

      breakdown.add(PassAnalytics(
        passType: passType,
        count: typePasses.length,
        totalValue: typePasses.fold<double>(0.0, (sum, p) => sum + p.amount),
        expectedCheckIns: typePasses.length,
        expectedCheckOuts: typePasses.length,
        missedScans: 0, // Would be calculated from actual scan data
        startDate: dateRange.start,
        endDate: dateRange.end,
      ));
    }

    return {
      'activePasses': activePasses,
      'expiredPasses': expiredPasses,
      'upcomingPasses': upcomingPasses,
      'breakdown': breakdown,
    };
  }

  /// Calculate revenue analytics
  static Map<String, dynamic> _calculateRevenueAnalytics(
    List<PurchasedPass> passes,
    AnalyticsDateRange dateRange,
  ) {
    final expectedRevenue =
        passes.fold<double>(0.0, (sum, p) => sum + p.amount);
    final actualRevenue = passes
        .where((p) => p.currentStatus != 'cancelled')
        .fold<double>(0.0, (sum, p) => sum + p.amount);
    final missedRevenue = expectedRevenue - actualRevenue;

    // Calculate daily revenue breakdown
    final List<RevenueByDay> dailyRevenue = [];
    final currentDate = DateTime(
        dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final endDate =
        DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);

    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final nextDay = currentDate.add(const Duration(days: 1));
      final dayPasses = passes
          .where((p) =>
              p.issuedAt.isAfter(currentDate) && p.issuedAt.isBefore(nextDay))
          .toList();

      dailyRevenue.add(RevenueByDay(
        date: currentDate,
        expectedRevenue:
            dayPasses.fold<double>(0.0, (sum, p) => sum + p.amount),
        actualRevenue: dayPasses
            .where((p) => p.currentStatus != 'cancelled')
            .fold<double>(0.0, (sum, p) => sum + p.amount),
        passCount: dayPasses.length,
        checkIns:
            dayPasses.where((p) => p.currentStatus == 'checked_in').length,
        checkOuts:
            dayPasses.where((p) => p.currentStatus == 'checked_out').length,
      ));

      currentDate.add(const Duration(days: 1));
    }

    return {
      'expectedRevenue': expectedRevenue,
      'actualRevenue': actualRevenue,
      'missedRevenue': missedRevenue > 0 ? missedRevenue : 0.0,
      'dailyRevenue': dailyRevenue,
    };
  }

  /// Calculate time-based analytics
  static Map<String, dynamic> _calculateTimeBasedAnalytics(
    List<PurchasedPass> passes,
    AnalyticsDateRange dateRange,
  ) {
    // Calculate hourly distribution
    final Map<String, int> hourlyDistribution = {};
    for (int hour = 0; hour < 24; hour++) {
      hourlyDistribution['${hour.toString().padLeft(2, '0')}:00'] = 0;
    }

    for (final pass in passes) {
      final hour = '${pass.issuedAt.hour.toString().padLeft(2, '0')}:00';
      hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
    }

    // Find peak traffic time
    String peakTrafficTime = '12:00';
    int maxCount = 0;
    for (final entry in hourlyDistribution.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        peakTrafficTime = entry.key;
      }
    }

    // Calculate traffic flow data
    final List<TrafficFlowData> trafficFlow = [];
    // This would be more complex with actual check-in/check-out data
    // For now, we'll create sample data based on passes

    return {
      'peakTrafficTime': peakTrafficTime,
      'hourlyDistribution': hourlyDistribution,
      'trafficFlow': trafficFlow,
    };
  }

  /// Get date range based on filter
  static AnalyticsDateRange _getDateRange(
    String dateFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (dateFilter) {
      case 'today':
        return AnalyticsDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case 'tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        return AnalyticsDateRange(
          start: tomorrow,
          end: tomorrow.add(const Duration(days: 1)),
        );
      case 'next_week':
        final nextWeekStart = today.add(Duration(days: 7 - now.weekday + 1));
        return AnalyticsDateRange(
          start: nextWeekStart,
          end: nextWeekStart.add(const Duration(days: 7)),
        );
      case 'next_month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final nextMonthEnd = DateTime(now.year, now.month + 2, 0);
        return AnalyticsDateRange(
          start: nextMonth,
          end: nextMonthEnd,
        );
      case 'custom':
        return AnalyticsDateRange(
          start: customStartDate ?? today,
          end: customEndDate ?? today.add(const Duration(days: 1)),
        );
      default:
        return AnalyticsDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
    }
  }

  /// Get comparison date range
  static AnalyticsDateRange _getComparisonDateRange(
    AnalyticsDateRange currentRange,
    String comparisonType,
  ) {
    final duration = currentRange.end.difference(currentRange.start);

    switch (comparisonType) {
      case 'previous_period':
        return AnalyticsDateRange(
          start: currentRange.start.subtract(duration),
          end: currentRange.start,
        );
      case 'same_period_last_year':
        return AnalyticsDateRange(
          start: DateTime(
            currentRange.start.year - 1,
            currentRange.start.month,
            currentRange.start.day,
          ),
          end: DateTime(
            currentRange.end.year - 1,
            currentRange.end.month,
            currentRange.end.day,
          ),
        );
      default:
        return AnalyticsDateRange(
          start: currentRange.start.subtract(duration),
          end: currentRange.start,
        );
    }
  }

  /// Helper methods
  static String _getVehicleTypeFromPass(PurchasedPass pass) {
    // This would ideally come from the vehicle_types table
    // For now, we'll extract from vehicle description or use a default
    final description = pass.vehicleDescription.toLowerCase();
    if (description.contains('car') || description.contains('sedan'))
      return 'Car';
    if (description.contains('truck') || description.contains('lorry'))
      return 'Truck';
    if (description.contains('bus')) return 'Bus';
    if (description.contains('motorcycle') || description.contains('bike'))
      return 'Motorcycle';
    if (description.contains('van')) return 'Van';
    return 'Other';
  }

  static String _getPassTypeFromDescription(String description) {
    final lowerDesc = description.toLowerCase();
    if (lowerDesc.contains('tourist')) return 'Tourist';
    if (lowerDesc.contains('business')) return 'Business';
    if (lowerDesc.contains('transit')) return 'Transit';
    if (lowerDesc.contains('commercial')) return 'Commercial';
    if (lowerDesc.contains('diplomatic')) return 'Diplomatic';
    return 'General';
  }

  static String _getTopVehicleType(
      Map<String, VehicleTypeAnalytics> breakdown) {
    if (breakdown.isEmpty) return 'N/A';

    String topType = 'N/A';
    int maxCount = 0;

    for (final entry in breakdown.entries) {
      final totalCount =
          entry.value.expectedCheckIns + entry.value.expectedCheckOuts;
      if (totalCount > maxCount) {
        maxCount = totalCount;
        topType = entry.key;
      }
    }

    return topType;
  }
}

/// Date range helper class
class AnalyticsDateRange {
  final DateTime start;
  final DateTime end;

  AnalyticsDateRange({required this.start, required this.end});
}
