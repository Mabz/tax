import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';

/// Business Intelligence Service
/// Provides analytics and insights data for BI dashboards
class BusinessIntelligenceService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get dashboard overview data for an authority
  static Future<Map<String, dynamic>> getDashboardData(
      String authorityId) async {
    try {
      debugPrint('🔍 Fetching dashboard data for authority: $authorityId');

      // Get all passes for the authority with simple query
      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId);

      final passes =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      // Calculate metrics
      final now = DateTime.now();
      final totalPasses = passes.length;
      final activePasses =
          passes.where((p) => !p.isExpired && p.status == 'active').length;
      final expiredPasses = passes.where((p) => p.isExpired).length;
      final totalRevenue = passes.fold<double>(0.0, (sum, p) => sum + p.amount);

      // Non-compliance metrics
      final expiredButActive = passes
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .length;
      final overstayedVehicles = passes
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .length;

      // Calculate compliance rate
      final totalActiveOrExpired =
          passes.where((p) => p.status == 'active' || p.isExpired).length;
      final compliantPasses = totalActiveOrExpired - expiredButActive;
      final complianceRate = totalActiveOrExpired > 0
          ? (compliantPasses / totalActiveOrExpired * 100)
          : 100.0;

      // Monthly revenue (current month)
      final currentMonth = DateTime(now.year, now.month);
      final monthlyRevenue = passes
          .where((p) => p.issuedAt.isAfter(currentMonth))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      // Vehicle count
      final uniqueVehicles = passes
          .where((p) =>
              p.vehicleRegistrationNumber != null &&
              p.vehicleRegistrationNumber!.isNotEmpty)
          .map((p) => p.vehicleRegistrationNumber)
          .toSet()
          .length;

      // Border crossings (entries used)
      final borderCrossings = passes.fold<int>(
          0, (sum, p) => sum + (p.entryLimit - p.entriesRemaining));

      debugPrint(
          '✅ Dashboard data calculated: $totalPasses passes, \$${totalRevenue.toStringAsFixed(2)} revenue');

      return {
        'totalPasses': totalPasses,
        'activePasses': activePasses,
        'expiredPasses': expiredPasses,
        'totalRevenue': totalRevenue,
        'monthlyRevenue': monthlyRevenue,
        'totalVehicles': uniqueVehicles,
        'activeVehicles':
            passes.where((p) => p.currentStatus == 'checked_in').length,
        'borderCrossings': borderCrossings,
        'complianceRate': complianceRate,
        'expiredButActive': expiredButActive,
        'overstayedVehicles': overstayedVehicles,
        'fraudAlerts': 0, // TODO: Implement fraud detection logic
        'revenueAtRisk': passes
            .where((p) => p.isExpired && p.currentStatus == 'checked_in')
            .fold<double>(0.0, (sum, p) => sum + p.amount),
      };
    } catch (e) {
      debugPrint('❌ Error fetching dashboard data: $e');
      rethrow;
    }
  }

  /// Get pass analytics data for an authority
  static Future<Map<String, dynamic>> getPassAnalyticsData(String authorityId,
      {String period = 'all_time',
      DateTime? customStartDate,
      DateTime? customEndDate,
      String borderFilter = 'any_border'}) async {
    try {
      debugPrint('🔍 Fetching pass analytics for authority: $authorityId');

      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId);

      final allPasses =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      // Filter passes based on period
      final passes = _filterPassesByPeriod(
          allPasses, period, customStartDate, customEndDate);

      // Basic metrics
      final totalPasses = passes.length;
      final activePasses =
          passes.where((p) => !p.isExpired && p.status == 'active').length;
      final expiredPasses = passes.where((p) => p.isExpired).length;

      // Non-compliance detection
      final expiredButActive = passes
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .toList();
      final overstayedVehicles = passes
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .toList();

      // Calculate compliance rate
      final totalActiveOrExpired =
          passes.where((p) => p.status == 'active' || p.isExpired).length;
      final compliantPasses = totalActiveOrExpired - expiredButActive.length;
      final complianceRate = totalActiveOrExpired > 0
          ? (compliantPasses / totalActiveOrExpired * 100)
          : 100.0;

      // Pass type distribution
      final passTypeMap = <String, int>{};
      for (final pass in passes) {
        final type = _getPassType(pass.passDescription);
        passTypeMap[type] = (passTypeMap[type] ?? 0) + 1;
      }

      // Revenue at risk from non-compliant passes
      final revenueAtRisk =
          expiredButActive.fold<double>(0.0, (sum, p) => sum + p.amount);

      // Monthly trends (last 6 months)
      final monthlyTrends = <Map<String, dynamic>>[];
      final now = DateTime.now();
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final nextMonth = DateTime(now.year, now.month - i + 1);

        final monthPasses = passes
            .where((p) =>
                p.issuedAt.isAfter(month) && p.issuedAt.isBefore(nextMonth))
            .toList();

        monthlyTrends.add({
          'month': _getMonthName(month.month),
          'passes': monthPasses.length,
          'revenue': monthPasses.fold<double>(0.0, (sum, p) => sum + p.amount),
        });
      }

      // Get available entry points (deduplicated)
      final entryPointMap = <String, String>{};
      for (final pass in passes) {
        if (pass.entryPointName != null && pass.entryPointName!.isNotEmpty) {
          final id = pass.entryPointId ?? pass.entryPointName!;
          entryPointMap[id] = pass.entryPointName!;
        }
      }
      final availableBorders = entryPointMap.entries
          .map((entry) => {
                'id': entry.key,
                'name': entry.value,
              })
          .toList();

      // Calculate top passes by entry point
      final filteredPasses = borderFilter == 'any_border'
          ? passes
          : passes
              .where((p) =>
                  p.entryPointId == borderFilter ||
                  p.entryPointName == borderFilter)
              .toList();

      // Group passes by template (passDescription + amount + entryLimit)
      final passTemplateMap = <String, Map<String, dynamic>>{};
      for (final pass in filteredPasses) {
        final key = '${pass.passDescription}_${pass.amount}_${pass.entryLimit}';
        if (passTemplateMap.containsKey(key)) {
          passTemplateMap[key]!['count'] =
              (passTemplateMap[key]!['count'] as int) + 1;
        } else {
          passTemplateMap[key] = {
            'passDescription': pass.passDescription,
            'borderName': pass.entryPointName ?? 'Any Entry Point',
            'count': 1,
            'amount': pass.amount,
            'currency': pass.currency,
            'entryLimit': pass.entryLimit,
            'validityDays': _calculateValidityDays(pass.passDescription),
          };
        }
      }

      // Sort by count and take top 10
      final topPasses = passTemplateMap.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final top10Passes = topPasses.take(10).toList();

      // Calculate Quick Statistics (using filtered passes for border consistency)
      final quickStats =
          _calculateQuickStatistics(filteredPasses, borderFilter, period);

      debugPrint(
          '✅ Pass analytics calculated: ${expiredButActive.length} non-compliant passes');

      return {
        'totalPasses': totalPasses,
        'activePasses': activePasses,
        'expiredPasses': expiredPasses,
        'expiredButActive': expiredButActive.length,
        'overstayedVehicles': overstayedVehicles.length,
        'fraudAlerts': 0, // TODO: Implement fraud detection
        'complianceRate': complianceRate,
        'revenueAtRisk': revenueAtRisk,
        'passTypes': passTypeMap,
        'monthlyTrends': monthlyTrends,
        'topPasses': top10Passes,
        'availableBorders': availableBorders,
        'quickStats': quickStats,
        'nonCompliantPasses': expiredButActive
            .map((p) => {
                  'passId': p.passId,
                  'vehicleDescription': p.vehicleDescription,
                  'vehicleRegistrationNumber': p.vehicleRegistrationNumber,
                  'passDescription': p.passDescription,
                  'expiresAt': p.expiresAt.toIso8601String(),
                  'currentStatus': p.currentStatus,
                  'amount': p.amount,
                  'daysOverdue': DateTime.now().difference(p.expiresAt).inDays,
                })
            .toList(),
      };
    } catch (e) {
      debugPrint('❌ Error fetching pass analytics: $e');
      rethrow;
    }
  }

  /// Get revenue analytics data for an authority
  static Future<Map<String, dynamic>> getRevenueAnalyticsData(
      String authorityId) async {
    try {
      debugPrint('🔍 Fetching revenue analytics for authority: $authorityId');

      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId);

      final passes =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      // Basic revenue metrics
      final totalRevenue = passes.fold<double>(0.0, (sum, p) => sum + p.amount);

      // Monthly revenue (current month)
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final monthlyRevenue = passes
          .where((p) => p.issuedAt.isAfter(currentMonth))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      // Daily average (last 30 days)
      final last30Days = now.subtract(const Duration(days: 30));
      final recent30DaysRevenue = passes
          .where((p) => p.issuedAt.isAfter(last30Days))
          .fold<double>(0.0, (sum, p) => sum + p.amount);
      final dailyAverage = recent30DaysRevenue / 30;

      // Revenue growth (compare last 30 days vs previous 30 days)
      final last60Days = now.subtract(const Duration(days: 60));
      final previous30DaysRevenue = passes
          .where((p) =>
              p.issuedAt.isAfter(last60Days) && p.issuedAt.isBefore(last30Days))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      final revenueGrowth = previous30DaysRevenue > 0
          ? ((recent30DaysRevenue - previous30DaysRevenue) /
              previous30DaysRevenue *
              100)
          : 0.0;

      // Yearly projection (based on current monthly average)
      final monthsOfData = passes.isNotEmpty
          ? now.difference(passes.first.issuedAt).inDays / 30.44
          : 1.0;
      final monthlyAverage =
          monthsOfData > 0 ? totalRevenue / monthsOfData : 0.0;
      final yearlyProjection = monthlyAverage * 12;

      // Revenue by pass type
      final revenueByPassType = <String, double>{};
      for (final pass in passes) {
        final type = _getPassType(pass.passDescription);
        revenueByPassType[type] =
            (revenueByPassType[type] ?? 0.0) + pass.amount;
      }

      // Revenue by payment method (simulated - you may have actual payment data)
      final revenueByPaymentMethod = <String, double>{
        'credit_card': totalRevenue * 0.6,
        'mobile_money': totalRevenue * 0.28,
        'bank_transfer': totalRevenue * 0.1,
        'cash': totalRevenue * 0.02,
      };

      // Revenue at risk from non-compliance
      final revenueAtRisk = passes
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      // Outstanding payments (simulated - passes issued but not fully processed)
      final outstandingPayments = passes
          .where((p) => p.status == 'pending' || p.status == 'processing')
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      // Collection efficiency
      final expectedRevenue = totalRevenue + outstandingPayments;
      final collectionEfficiency =
          expectedRevenue > 0 ? (totalRevenue / expectedRevenue * 100) : 100.0;

      // Monthly trends (last 6 months)
      final monthlyTrends = <Map<String, dynamic>>[];
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final nextMonth = DateTime(now.year, now.month - i + 1);

        final monthRevenue = passes
            .where((p) =>
                p.issuedAt.isAfter(month) && p.issuedAt.isBefore(nextMonth))
            .fold<double>(0.0, (sum, p) => sum + p.amount);

        // Simple target calculation (10% growth month over month)
        final target =
            i == 5 ? monthRevenue : monthlyTrends.last['revenue'] * 1.1;

        monthlyTrends.add({
          'month': _getMonthName(month.month),
          'revenue': monthRevenue,
          'target': target,
        });
      }

      // Top revenue source
      final topRevenueSource = revenueByPassType.entries.isNotEmpty
          ? revenueByPassType.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : 'Unknown';

      debugPrint(
          '✅ Revenue analytics calculated: \$${totalRevenue.toStringAsFixed(2)} total revenue');

      return {
        'totalRevenue': totalRevenue,
        'monthlyRevenue': monthlyRevenue,
        'dailyAverage': dailyAverage,
        'yearlyProjection': yearlyProjection,
        'revenueGrowth': revenueGrowth,
        'topRevenueSource': '${topRevenueSource.toUpperCase()} Passes',
        'revenueByPassType': revenueByPassType,
        'revenueByPaymentMethod': revenueByPaymentMethod,
        'monthlyTrends': monthlyTrends,
        'revenueAtRisk': revenueAtRisk,
        'collectionEfficiency': collectionEfficiency,
        'outstandingPayments': outstandingPayments,
      };
    } catch (e) {
      debugPrint('❌ Error fetching revenue analytics: $e');
      rethrow;
    }
  }

  /// Get recent activity for dashboard
  static Future<List<Map<String, dynamic>>> getRecentActivity(
      String authorityId,
      {int limit = 10}) async {
    try {
      debugPrint('🔍 Fetching recent activity for authority: $authorityId');

      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId)
          .order('issued_at', ascending: false)
          .limit(limit);

      final passes =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      final activities = <Map<String, dynamic>>[];

      for (final pass in passes) {
        // Add pass purchase activity
        activities.add({
          'title': 'New pass purchased',
          'subtitle':
              '${pass.vehicleDescription} purchased ${pass.passDescription}',
          'time': _getTimeAgo(pass.issuedAt),
          'icon': 'add_circle',
          'color': 'green',
        });

        // Add expiration warnings for passes expiring soon
        if (!pass.isExpired &&
            pass.expiresAt.difference(DateTime.now()).inDays <= 1) {
          activities.add({
            'title': 'Pass expiring soon',
            'subtitle':
                '${pass.vehicleDescription} pass expires ${_getTimeAgo(pass.expiresAt)}',
            'time': _getTimeAgo(pass.expiresAt),
            'icon': 'warning',
            'color': 'orange',
          });
        }

        // Add non-compliance alerts
        if (pass.isExpired && pass.currentStatus == 'checked_in') {
          activities.add({
            'title': 'Non-compliance alert',
            'subtitle':
                '${pass.vehicleDescription} overstaying with expired pass',
            'time': _getTimeAgo(pass.expiresAt),
            'icon': 'security',
            'color': 'red',
          });
        }
      }

      // Sort by most recent and limit
      activities.sort((a, b) => b['time'].compareTo(a['time']));

      debugPrint('✅ Recent activity fetched: ${activities.length} activities');

      return activities.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error fetching recent activity: $e');
      return [];
    }
  }

  /// Get non-compliant passes with detailed information
  static Future<List<Map<String, dynamic>>> getNonCompliantPasses(
      String authorityId) async {
    try {
      debugPrint(
          '🔍 Fetching non-compliant passes for authority: $authorityId');

      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId)
          .lt('expires_at', DateTime.now().toIso8601String())
          .eq('current_status', 'checked_in');

      final passes =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      return passes
          .map((pass) => {
                'passId': pass.passId,
                'vehicleDescription': pass.vehicleDescription,
                'vehicleRegistrationNumber':
                    pass.vehicleRegistrationNumber ?? 'N/A',
                'passDescription': pass.passDescription,
                'expiresAt': pass.expiresAt,
                'currentStatus': pass.currentStatus,
                'amount': pass.amount,
                'currency': pass.currency,
                'daysOverdue': DateTime.now().difference(pass.expiresAt).inDays,
                'borderName': pass.entryPointName ?? 'Unknown',
                'issuedAt': pass.issuedAt,
              })
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching non-compliant passes: $e');
      rethrow;
    }
  }

  /// Helper method to determine pass type from description
  static String _getPassType(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('daily') || desc.contains('1 day')) return 'daily';
    if (desc.contains('weekly') || desc.contains('7 day')) return 'weekly';
    if (desc.contains('monthly') || desc.contains('30 day')) return 'monthly';
    if (desc.contains('annual') ||
        desc.contains('yearly') ||
        desc.contains('365 day')) return 'annual';
    return 'other';
  }

  /// Helper method to get month name
  static String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  /// Helper method to calculate validity days from pass description
  static int _calculateValidityDays(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('1 day') || desc.contains('daily')) return 1;
    if (desc.contains('7 day') || desc.contains('weekly')) return 7;
    if (desc.contains('30 day') || desc.contains('monthly')) return 30;
    if (desc.contains('365 day') ||
        desc.contains('annual') ||
        desc.contains('yearly')) return 365;

    // Try to extract number + day pattern
    final dayMatch = RegExp(r'(\d+)\s*day').firstMatch(desc);
    if (dayMatch != null) {
      return int.tryParse(dayMatch.group(1) ?? '0') ?? 0;
    }

    return 0; // Unknown
  }

  /// Calculate quick statistics from pass data
  static Map<String, dynamic> _calculateQuickStatistics(
      List<PurchasedPass> passes, String borderFilter, String period) {
    if (passes.isEmpty) {
      return {
        'averagePassDuration': '0 days',
        'peakUsageDay': 'No data',
        'averageProcessingTime': '0 minutes',
        'borderFilter': borderFilter,
        'period': period,
        'passCount': 0,
      };
    }

    // 1. Average Pass Duration
    final totalDurationDays = passes.fold<int>(0, (sum, pass) {
      return sum + pass.expiresAt.difference(pass.activationDate).inDays;
    });
    final averageDuration =
        (totalDurationDays / passes.length).toStringAsFixed(1);

    // 2. Peak Usage Day
    final dayOfWeekCounts = <int, int>{};
    for (final pass in passes) {
      final dayOfWeek = pass.issuedAt.weekday; // 1=Monday, 7=Sunday
      dayOfWeekCounts[dayOfWeek] = (dayOfWeekCounts[dayOfWeek] ?? 0) + 1;
    }
    final peakDayEntry = dayOfWeekCounts.entries.isNotEmpty
        ? dayOfWeekCounts.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final peakDay =
        peakDayEntry != null ? _getDayName(peakDayEntry.key) : 'No data';

    // 3. Average Processing Time (time between activation and issuance)
    final totalProcessingMinutes = passes.fold<int>(0, (sum, pass) {
      // Calculate time between issuance and activation
      final processingTime =
          pass.activationDate.difference(pass.issuedAt).inMinutes.abs();
      return sum + processingTime;
    });
    final averageProcessing =
        (totalProcessingMinutes / passes.length).toStringAsFixed(1);

    return {
      'averagePassDuration': '$averageDuration days',
      'peakUsageDay': peakDay,
      'averageProcessingTime': '$averageProcessing minutes',
      'borderFilter': borderFilter,
      'period': period,
      'passCount': passes.length,
    };
  }

  /// Helper method to get day name from weekday number
  static String _getDayName(int weekday) {
    const days = [
      'Monday', // 1
      'Tuesday', // 2
      'Wednesday', // 3
      'Thursday', // 4
      'Friday', // 5
      'Saturday', // 6
      'Sunday', // 7
    ];
    return days[weekday - 1];
  }

  /// Helper method to get time ago string
  static String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Helper method to filter passes by time period
  static List<PurchasedPass> _filterPassesByPeriod(List<PurchasedPass> passes,
      String period, DateTime? customStartDate, DateTime? customEndDate) {
    final now = DateTime.now();

    switch (period) {
      case 'current_month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return passes.where((p) => p.issuedAt.isAfter(startOfMonth)).toList();

      case 'last_month':
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final endOfLastMonth = DateTime(now.year, now.month, 1);
        return passes
            .where((p) =>
                p.issuedAt.isAfter(startOfLastMonth) &&
                p.issuedAt.isBefore(endOfLastMonth))
            .toList();

      case 'last_3_months':
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        return passes.where((p) => p.issuedAt.isAfter(threeMonthsAgo)).toList();

      case 'last_6_months':
        final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
        return passes.where((p) => p.issuedAt.isAfter(sixMonthsAgo)).toList();

      case 'custom':
        if (customStartDate != null && customEndDate != null) {
          // Add time to make end date inclusive (end of day)
          final endDateInclusive = DateTime(customEndDate.year,
              customEndDate.month, customEndDate.day, 23, 59, 59);
          return passes
              .where((p) =>
                  p.issuedAt.isAfter(customStartDate) &&
                  p.issuedAt.isBefore(endDateInclusive))
              .toList();
        }
        return passes;

      default: // 'all_time'
        return passes;
    }
  }
}
