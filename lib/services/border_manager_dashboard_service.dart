import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import 'border_manager_service.dart';

/// Dashboard data model for border managers
class DashboardData {
  final int totalPasses;
  final int activePasses;
  final int expiredPasses;
  final int vehiclesInCountry;
  final double totalRevenue;
  final double monthlyRevenue;
  final List<PassActivity> recentActivity;
  final List<ChartData> passesOverTime;
  final List<ChartData> revenueOverTime;
  final Map<String, int> passTypeDistribution;
  final List<VehicleAlert> alerts;

  DashboardData({
    required this.totalPasses,
    required this.activePasses,
    required this.expiredPasses,
    required this.vehiclesInCountry,
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.recentActivity,
    required this.passesOverTime,
    required this.revenueOverTime,
    required this.passTypeDistribution,
    required this.alerts,
  });
}

/// Chart data model for dashboard charts
class ChartData {
  final String label;
  final double value;
  final DateTime date;

  ChartData({
    required this.label,
    required this.value,
    required this.date,
  });
}

/// Pass activity model for recent activity feed
class PassActivity {
  final String id;
  final String description;
  final String vehicleInfo;
  final DateTime timestamp;
  final String type; // 'purchase', 'checkin', 'checkout', 'expired'
  final String status;

  PassActivity({
    required this.id,
    required this.description,
    required this.vehicleInfo,
    required this.timestamp,
    required this.type,
    required this.status,
  });
}

/// Vehicle alert model for dashboard alerts
class VehicleAlert {
  final String id;
  final String title;
  final String description;
  final String severity; // 'low', 'medium', 'high'
  final String vehicleInfo;
  final DateTime timestamp;
  final String type; // 'overstay', 'expired', 'suspicious'

  VehicleAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.vehicleInfo,
    required this.timestamp,
    required this.type,
  });
}

/// Border Manager Dashboard Service
class BorderManagerDashboardService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get dashboard data for a specific border
  static Future<DashboardData> getDashboardDataForBorder(
    String borderId,
    String timeframe,
  ) async {
    try {
      debugPrint(
          '🔍 Fetching dashboard data for border: $borderId, timeframe: $timeframe');

      // Get passes for this border
      final passesResponse = await _supabase
          .from('purchased_passes')
          .select('*')
          .or('entry_point_id.eq.$borderId,exit_point_id.eq.$borderId');

      final allPasses =
          passesResponse.map((json) => PurchasedPass.fromJson(json)).toList();

      // Filter passes by timeframe
      final filteredPasses = _filterPassesByTimeframe(allPasses, timeframe);

      // Calculate basic metrics
      final totalPasses = filteredPasses.length;
      final activePasses = filteredPasses.where((p) => p.isActive).length;
      final expiredPasses = filteredPasses.where((p) => p.isExpired).length;
      final vehiclesInCountry =
          filteredPasses.where((p) => p.currentStatus == 'checked_in').length;
      final totalRevenue =
          filteredPasses.fold<double>(0.0, (sum, p) => sum + p.amount);

      // Calculate monthly revenue (current month)
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final monthlyRevenue = filteredPasses
          .where((p) => p.issuedAt.isAfter(currentMonth))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      // Generate recent activity
      final recentActivity = _generateRecentActivity(filteredPasses);

      // Generate chart data
      final passesOverTime =
          _generatePassesOverTimeData(filteredPasses, timeframe);
      final revenueOverTime =
          _generateRevenueOverTimeData(filteredPasses, timeframe);

      // Calculate pass type distribution
      final passTypeDistribution = <String, int>{};
      for (final pass in filteredPasses) {
        final type = _getPassType(pass.passDescription);
        passTypeDistribution[type] = (passTypeDistribution[type] ?? 0) + 1;
      }

      // Generate alerts
      final alerts = _generateAlerts(filteredPasses);

      debugPrint(
          '✅ Dashboard data generated: $totalPasses passes, \$${totalRevenue.toStringAsFixed(2)} revenue');

      return DashboardData(
        totalPasses: totalPasses,
        activePasses: activePasses,
        expiredPasses: expiredPasses,
        vehiclesInCountry: vehiclesInCountry,
        totalRevenue: totalRevenue,
        monthlyRevenue: monthlyRevenue,
        recentActivity: recentActivity,
        passesOverTime: passesOverTime,
        revenueOverTime: revenueOverTime,
        passTypeDistribution: passTypeDistribution,
        alerts: alerts,
      );
    } catch (e) {
      debugPrint('❌ Error fetching dashboard data: $e');
      throw Exception('Failed to fetch dashboard data: $e');
    }
  }

  /// Get dashboard data for all borders assigned to current manager
  static Future<DashboardData> getDashboardDataForManager(
      String timeframe) async {
    try {
      debugPrint(
          '🔍 Fetching dashboard data for current manager, timeframe: $timeframe');

      // Get assigned borders for current manager
      final assignedBorders =
          await BorderManagerService.getAssignedBordersForCurrentManager();

      if (assignedBorders.isEmpty) {
        return DashboardData(
          totalPasses: 0,
          activePasses: 0,
          expiredPasses: 0,
          vehiclesInCountry: 0,
          totalRevenue: 0.0,
          monthlyRevenue: 0.0,
          recentActivity: [],
          passesOverTime: [],
          revenueOverTime: [],
          passTypeDistribution: {},
          alerts: [],
        );
      }

      // Get passes for all assigned borders
      final borderIds = assignedBorders.map((b) => b.id).toList();
      final passesResponse = await _supabase
          .from('purchased_passes')
          .select('*')
          .or(borderIds
              .map((id) => 'entry_point_id.eq.$id,exit_point_id.eq.$id')
              .join(','));

      final allPasses =
          passesResponse.map((json) => PurchasedPass.fromJson(json)).toList();

      // Filter passes by timeframe
      final filteredPasses = _filterPassesByTimeframe(allPasses, timeframe);

      // Calculate metrics (same as border-specific method)
      final totalPasses = filteredPasses.length;
      final activePasses = filteredPasses.where((p) => p.isActive).length;
      final expiredPasses = filteredPasses.where((p) => p.isExpired).length;
      final vehiclesInCountry =
          filteredPasses.where((p) => p.currentStatus == 'checked_in').length;
      final totalRevenue =
          filteredPasses.fold<double>(0.0, (sum, p) => sum + p.amount);

      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final monthlyRevenue = filteredPasses
          .where((p) => p.issuedAt.isAfter(currentMonth))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      final recentActivity = _generateRecentActivity(filteredPasses);
      final passesOverTime =
          _generatePassesOverTimeData(filteredPasses, timeframe);
      final revenueOverTime =
          _generateRevenueOverTimeData(filteredPasses, timeframe);

      final passTypeDistribution = <String, int>{};
      for (final pass in filteredPasses) {
        final type = _getPassType(pass.passDescription);
        passTypeDistribution[type] = (passTypeDistribution[type] ?? 0) + 1;
      }

      final alerts = _generateAlerts(filteredPasses);

      debugPrint(
          '✅ Manager dashboard data generated: $totalPasses passes across ${assignedBorders.length} borders');

      return DashboardData(
        totalPasses: totalPasses,
        activePasses: activePasses,
        expiredPasses: expiredPasses,
        vehiclesInCountry: vehiclesInCountry,
        totalRevenue: totalRevenue,
        monthlyRevenue: monthlyRevenue,
        recentActivity: recentActivity,
        passesOverTime: passesOverTime,
        revenueOverTime: revenueOverTime,
        passTypeDistribution: passTypeDistribution,
        alerts: alerts,
      );
    } catch (e) {
      debugPrint('❌ Error fetching manager dashboard data: $e');
      throw Exception('Failed to fetch manager dashboard data: $e');
    }
  }

  /// Filter passes by timeframe
  static List<PurchasedPass> _filterPassesByTimeframe(
      List<PurchasedPass> passes, String timeframe) {
    final now = DateTime.now();
    DateTime cutoffDate;

    switch (timeframe) {
      case '1d':
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case '7d':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      case '90d':
        cutoffDate = now.subtract(const Duration(days: 90));
        break;
      default:
        cutoffDate = now.subtract(const Duration(days: 7));
    }

    return passes.where((p) => p.issuedAt.isAfter(cutoffDate)).toList();
  }

  /// Generate recent activity from passes
  static List<PassActivity> _generateRecentActivity(
      List<PurchasedPass> passes) {
    final activities = <PassActivity>[];

    // Sort passes by issued date (most recent first)
    final sortedPasses = List<PurchasedPass>.from(passes)
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    for (final pass in sortedPasses.take(10)) {
      // Add pass purchase activity
      activities.add(PassActivity(
        id: '${pass.passId}_purchase',
        description: 'Pass purchased',
        vehicleInfo: pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
        timestamp: pass.issuedAt,
        type: 'purchase',
        status: pass.status,
      ));

      // Add check-in activity if vehicle is in country
      if (pass.currentStatus == 'checked_in') {
        activities.add(PassActivity(
          id: '${pass.passId}_checkin',
          description: 'Vehicle entered country',
          vehicleInfo:
              pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
          timestamp:
              pass.issuedAt, // Approximate - we don't have actual check-in time
          type: 'checkin',
          status: 'active',
        ));
      }

      // Add expiration alerts
      if (pass.isExpired && pass.currentStatus == 'checked_in') {
        activities.add(PassActivity(
          id: '${pass.passId}_expired',
          description: 'Pass expired - vehicle overstaying',
          vehicleInfo:
              pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
          timestamp: pass.expiresAt,
          type: 'expired',
          status: 'alert',
        ));
      }
    }

    // Sort activities by timestamp (most recent first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(20).toList();
  }

  /// Generate passes over time chart data
  static List<ChartData> _generatePassesOverTimeData(
      List<PurchasedPass> passes, String timeframe) {
    final chartData = <ChartData>[];
    final now = DateTime.now();

    int days;
    switch (timeframe) {
      case '1d':
        days = 1;
        break;
      case '7d':
        days = 7;
        break;
      case '30d':
        days = 30;
        break;
      case '90d':
        days = 90;
        break;
      default:
        days = 7;
    }

    // Group passes by day
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final nextDate = date.add(const Duration(days: 1));

      final dayPasses = passes
          .where(
              (p) => p.issuedAt.isAfter(date) && p.issuedAt.isBefore(nextDate))
          .length;

      chartData.add(ChartData(
        label: '${date.day}/${date.month}',
        value: dayPasses.toDouble(),
        date: date,
      ));
    }

    return chartData;
  }

  /// Generate revenue over time chart data
  static List<ChartData> _generateRevenueOverTimeData(
      List<PurchasedPass> passes, String timeframe) {
    final chartData = <ChartData>[];
    final now = DateTime.now();

    int days;
    switch (timeframe) {
      case '1d':
        days = 1;
        break;
      case '7d':
        days = 7;
        break;
      case '30d':
        days = 30;
        break;
      case '90d':
        days = 90;
        break;
      default:
        days = 7;
    }

    // Group revenue by day
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final nextDate = date.add(const Duration(days: 1));

      final dayRevenue = passes
          .where(
              (p) => p.issuedAt.isAfter(date) && p.issuedAt.isBefore(nextDate))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      chartData.add(ChartData(
        label: '${date.day}/${date.month}',
        value: dayRevenue,
        date: date,
      ));
    }

    return chartData;
  }

  /// Generate alerts from passes
  static List<VehicleAlert> _generateAlerts(List<PurchasedPass> passes) {
    final alerts = <VehicleAlert>[];

    // Find overstaying vehicles
    final overstayingPasses = passes
        .where((p) => p.isExpired && p.currentStatus == 'checked_in')
        .toList();

    for (final pass in overstayingPasses) {
      final daysOverdue = DateTime.now().difference(pass.expiresAt).inDays;
      alerts.add(VehicleAlert(
        id: '${pass.passId}_overstay',
        title: 'Vehicle Overstaying',
        description: 'Pass expired $daysOverdue days ago',
        severity: daysOverdue > 7
            ? 'high'
            : daysOverdue > 3
                ? 'medium'
                : 'low',
        vehicleInfo: pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
        timestamp: pass.expiresAt,
        type: 'overstay',
      ));
    }

    // Find passes expiring soon
    final now = DateTime.now();
    final soonToExpire = passes
        .where((p) =>
            !p.isExpired &&
            p.currentStatus == 'checked_in' &&
            p.expiresAt.difference(now).inDays <= 1)
        .toList();

    for (final pass in soonToExpire) {
      final hoursLeft = pass.expiresAt.difference(now).inHours;
      alerts.add(VehicleAlert(
        id: '${pass.passId}_expiring',
        title: 'Pass Expiring Soon',
        description: 'Pass expires in $hoursLeft hours',
        severity: hoursLeft <= 6 ? 'high' : 'medium',
        vehicleInfo: pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
        timestamp: now,
        type: 'expired',
      ));
    }

    // Sort alerts by severity and timestamp
    alerts.sort((a, b) {
      const severityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final aSeverity = severityOrder[a.severity] ?? 3;
      final bSeverity = severityOrder[b.severity] ?? 3;

      if (aSeverity != bSeverity) {
        return aSeverity.compareTo(bSeverity);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return alerts;
  }

  /// Get pass type from description
  static String _getPassType(String description) {
    final lowerDesc = description.toLowerCase();
    if (lowerDesc.contains('tourist')) return 'Tourist';
    if (lowerDesc.contains('business')) return 'Business';
    if (lowerDesc.contains('transit')) return 'Transit';
    if (lowerDesc.contains('commercial')) return 'Commercial';
    if (lowerDesc.contains('diplomatic')) return 'Diplomatic';
    return 'General';
  }
}
