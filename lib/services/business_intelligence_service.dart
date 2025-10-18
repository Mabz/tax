import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import 'fraud_detection_service.dart';

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
        'fraudAlerts': (await FraudDetectionService.getFraudStatistics(
            authorityId))['total_alerts'],
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

      // Get authority details to fetch currency
      final authorityResponse = await _supabase
          .from('authorities')
          .select('default_currency_code')
          .eq('id', authorityId)
          .single();

      final authorityCurrency =
          authorityResponse['default_currency_code'] as String? ?? 'USD';

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

      // Revenue at risk from non-compliant passes (using authority currency)
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

      // Get available entry and exit points (deduplicated)
      final entryPointMap = <String, String>{};
      final exitPointMap = <String, String>{};

      for (final pass in passes) {
        // Entry points
        if (pass.entryPointName != null && pass.entryPointName!.isNotEmpty) {
          final id = pass.entryPointId ?? pass.entryPointName!;
          entryPointMap[id] = pass.entryPointName!;
        }
        // Exit points
        if (pass.exitPointName != null && pass.exitPointName!.isNotEmpty) {
          final id = pass.exitPointId ?? pass.exitPointName!;
          exitPointMap[id] = pass.exitPointName!;
        }
      }

      final availableEntryBorders = entryPointMap.entries
          .map((entry) => {
                'id': entry.key,
                'name': entry.value,
                'type': 'entry',
              })
          .toList();

      final availableExitBorders = exitPointMap.entries
          .map((entry) => {
                'id': entry.key,
                'name': entry.value,
                'type': 'exit',
              })
          .toList();

      // Legacy support - combined borders list
      final availableBorders = [
        ...availableEntryBorders,
        ...availableExitBorders
      ];

      // Calculate top passes by entry and exit points separately
      final filteredPasses = borderFilter == 'any_border'
          ? passes
          : passes
              .where((p) =>
                  p.entryPointId == borderFilter ||
                  p.entryPointName == borderFilter ||
                  p.exitPointId == borderFilter ||
                  p.exitPointName == borderFilter)
              .toList();

      // Group passes by template for entry points
      final entryPassTemplateMap = <String, Map<String, dynamic>>{};
      final exitPassTemplateMap = <String, Map<String, dynamic>>{};

      for (final pass in filteredPasses) {
        final key = '${pass.passDescription}_${pass.amount}_${pass.entryLimit}';

        // Entry point analysis
        if (pass.entryPointName != null && pass.entryPointName!.isNotEmpty) {
          if (entryPassTemplateMap.containsKey(key)) {
            entryPassTemplateMap[key]!['count'] =
                (entryPassTemplateMap[key]!['count'] as int) + 1;
          } else {
            entryPassTemplateMap[key] = {
              'passDescription': pass.passDescription,
              'borderName': pass.entryPointName!,
              'borderType': 'entry',
              'count': 1,
              'amount': pass.amount,
              'currency': pass.currency,
              'entryLimit': pass.entryLimit,
              'validityDays': _calculateValidityDays(pass.passDescription),
            };
          }
        }

        // Exit point analysis
        if (pass.exitPointName != null && pass.exitPointName!.isNotEmpty) {
          if (exitPassTemplateMap.containsKey(key)) {
            exitPassTemplateMap[key]!['count'] =
                (exitPassTemplateMap[key]!['count'] as int) + 1;
          } else {
            exitPassTemplateMap[key] = {
              'passDescription': pass.passDescription,
              'borderName': pass.exitPointName!,
              'borderType': 'exit',
              'count': 1,
              'amount': pass.amount,
              'currency': pass.currency,
              'entryLimit': pass.entryLimit,
              'validityDays': _calculateValidityDays(pass.passDescription),
            };
          }
        }
      }

      // Sort and get top 10 for each
      final topEntryPasses = entryPassTemplateMap.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final top10EntryPasses = topEntryPasses.take(10).toList();

      final topExitPasses = exitPassTemplateMap.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      final top10ExitPasses = topExitPasses.take(10).toList();

      // Legacy support - combined top passes
      final topPasses = [...topEntryPasses, ...topExitPasses]
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
        'overstayedVehicles': overstayedVehicles.length, // Consolidated metric
        'fraudAlerts': (await FraudDetectionService.getFraudStatistics(
            authorityId))['total_alerts'],
        'complianceRate': complianceRate,
        'revenueAtRisk': revenueAtRisk,
        'authorityCurrency': authorityCurrency,
        'passTypes': passTypeMap,
        'monthlyTrends': monthlyTrends,
        'topPasses': top10Passes, // Legacy support
        'topEntryPasses': top10EntryPasses,
        'topExitPasses': top10ExitPasses,
        'availableBorders': availableBorders, // Legacy support
        'availableEntryBorders': availableEntryBorders,
        'availableExitBorders': availableExitBorders,
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
                  'currency': p.currency,
                  'daysOverdue': DateTime.now().difference(p.expiresAt).inDays,
                  'entryPointName': p.entryPointName,
                  'exitPointName': p.exitPointName,
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

  /// Get non-compliance analytics with time period filtering
  static Future<Map<String, dynamic>> getNonComplianceAnalytics(
      String authorityId,
      {String period = 'all_time',
      DateTime? customStartDate,
      DateTime? customEndDate,
      String borderFilter = 'any_border',
      String entryBorderFilter = 'any_entry',
      String exitBorderFilter = 'any_exit'}) async {
    try {
      debugPrint(
          '🔍 Fetching non-compliance analytics for authority: $authorityId');

      // Get authority details to fetch currency
      final authorityResponse = await _supabase
          .from('authorities')
          .select('default_currency_code')
          .eq('id', authorityId)
          .single();

      final authorityCurrency =
          authorityResponse['default_currency_code'] as String? ?? 'USD';

      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId);

      final allPasses =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      // Filter passes based on period (for issued passes)
      final passes = _filterPassesByPeriod(
          allPasses, period, customStartDate, customEndDate);

      // Filter by borders if specified
      var filteredPasses = passes;

      // Apply entry border filter
      if (entryBorderFilter != 'any_entry') {
        filteredPasses = filteredPasses
            .where((p) =>
                p.entryPointId == entryBorderFilter ||
                p.entryPointName == entryBorderFilter)
            .toList();
      }

      // Apply exit border filter
      if (exitBorderFilter != 'any_exit') {
        filteredPasses = filteredPasses
            .where((p) =>
                p.exitPointId == exitBorderFilter ||
                p.exitPointName == exitBorderFilter)
            .toList();
      }

      // Legacy border filter support (for backward compatibility)
      if (borderFilter != 'any_border') {
        filteredPasses = filteredPasses
            .where((p) =>
                p.entryPointId == borderFilter ||
                p.entryPointName == borderFilter ||
                p.exitPointId == borderFilter ||
                p.exitPointName == borderFilter)
            .toList();
      }

      // Find expired passes still active (non-compliant)
      final expiredButActive = filteredPasses
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .toList();

      // Find overstayed vehicles (same as expired but active for now)
      final overstayedVehicles = expiredButActive;

      // Calculate revenue at risk using authority currency
      final revenueAtRisk =
          expiredButActive.fold<double>(0.0, (sum, p) => sum + p.amount);

      // Group by days overdue for analysis
      final overdueAnalysis = <String, int>{};
      for (final pass in expiredButActive) {
        final daysOverdue = DateTime.now().difference(pass.expiresAt).inDays;
        String category;
        if (daysOverdue <= 7) {
          category = '1-7 days';
        } else if (daysOverdue <= 30) {
          category = '8-30 days';
        } else if (daysOverdue <= 90) {
          category = '31-90 days';
        } else {
          category = '90+ days';
        }
        overdueAnalysis[category] = (overdueAnalysis[category] ?? 0) + 1;
      }

      // Get available entry and exit borders for filtering
      final entryPointMap = <String, String>{};
      final exitPointMap = <String, String>{};

      for (final pass in allPasses) {
        // Entry points
        if (pass.entryPointName != null && pass.entryPointName!.isNotEmpty) {
          final id = pass.entryPointId ?? pass.entryPointName!;
          entryPointMap[id] = pass.entryPointName!;
        }
        // Exit points
        if (pass.exitPointName != null && pass.exitPointName!.isNotEmpty) {
          final id = pass.exitPointId ?? pass.exitPointName!;
          exitPointMap[id] = pass.exitPointName!;
        }
      }

      final availableEntryBorders = entryPointMap.entries
          .map((entry) => {
                'id': entry.key,
                'name': entry.value,
                'type': 'entry',
              })
          .toList();

      final availableExitBorders = exitPointMap.entries
          .map((entry) => {
                'id': entry.key,
                'name': entry.value,
                'type': 'exit',
              })
          .toList();

      // Legacy support - combined borders list
      final availableBorders = [
        ...availableEntryBorders,
        ...availableExitBorders
      ];

      // Detailed non-compliant passes list
      final nonCompliantPassesList = expiredButActive
          .map((p) => {
                'passId': p.passId,
                'vehicleDescription': p.vehicleDescription,
                'vehicleRegistrationNumber':
                    p.vehicleRegistrationNumber ?? 'N/A',
                'passDescription': p.passDescription,
                'expiresAt': p.expiresAt.toIso8601String(),
                'currentStatus': p.currentStatus,
                'amount': p.amount,
                'currency': p.currency,
                'daysOverdue': DateTime.now().difference(p.expiresAt).inDays,
                'borderName': p.entryPointName ?? 'Unknown',
                'issuedAt': p.issuedAt.toIso8601String(),
              })
          .toList();

      // Sort by days overdue (most critical first)
      nonCompliantPassesList.sort((a, b) =>
          (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int));

      // Top 5 borders for non-compliance (entry and exit)
      final nonComplianceEntryBorders = <String, int>{};
      final nonComplianceExitBorders = <String, int>{};

      for (final pass in expiredButActive) {
        if (pass.entryPointName != null && pass.entryPointName!.isNotEmpty) {
          nonComplianceEntryBorders[pass.entryPointName!] =
              (nonComplianceEntryBorders[pass.entryPointName!] ?? 0) + 1;
        }
        if (pass.exitPointName != null && pass.exitPointName!.isNotEmpty) {
          nonComplianceExitBorders[pass.exitPointName!] =
              (nonComplianceExitBorders[pass.exitPointName!] ?? 0) + 1;
        }
      }

      final top5EntryBorders = nonComplianceEntryBorders.entries
          .map((e) => {'name': e.key, 'count': e.value, 'type': 'entry'})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final top5ExitBorders = nonComplianceExitBorders.entries
          .map((e) => {'name': e.key, 'count': e.value, 'type': 'exit'})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      debugPrint(
          '✅ Non-compliance analytics calculated: ${expiredButActive.length} violations');

      // Get illegal vehicles data
      final illegalVehiclesData = await _getIllegalVehiclesData(authorityId);

      return {
        'overstayedVehicles': overstayedVehicles.length,
        'illegalVehicles': illegalVehiclesData['count'],
        'illegalVehiclesList': illegalVehiclesData['vehicles'],
        'fraudAlerts': 0, // Placeholder for future fraud detection
        'revenueAtRisk': revenueAtRisk,
        'authorityCurrency': authorityCurrency,
        'overdueAnalysis': overdueAnalysis,
        'availableBorders': availableBorders,
        'availableEntryBorders': availableEntryBorders,
        'availableExitBorders': availableExitBorders,
        'nonCompliantPasses': nonCompliantPassesList,
        'top5EntryBorders': top5EntryBorders.take(5).toList(),
        'top5ExitBorders': top5ExitBorders.take(5).toList(),
        'period': period,
        'borderFilter': borderFilter,
        'totalPassesInPeriod': filteredPasses.length,
      };
    } catch (e) {
      debugPrint('❌ Error fetching non-compliance analytics: $e');
      rethrow;
    }
  }

  /// Get illegal vehicles data - vehicles found in-country but showing as departed
  static Future<Map<String, dynamic>> _getIllegalVehiclesData(
      String authorityId) async {
    try {
      debugPrint(
          '🔍 Fetching illegal vehicles data for authority: $authorityId');

      // Call the database function to get illegal vehicles
      final response =
          await _supabase.rpc('get_illegal_vehicles_in_country', params: {
        'p_authority_id': authorityId,
        'p_days_back': 30, // Look back 30 days
      });

      final vehicles = response as List<dynamic>? ?? [];

      debugPrint('✅ Found ${vehicles.length} illegal vehicles');

      return {
        'count': vehicles.length,
        'vehicles': vehicles,
      };
    } catch (e) {
      debugPrint('❌ Error fetching illegal vehicles data: $e');
      // Return empty data on error to prevent breaking the UI
      return {
        'count': 0,
        'vehicles': [],
      };
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

  /// Get detailed overstayed vehicles with owner information
  static Future<List<Map<String, dynamic>>> getOverstayedVehiclesDetails(
      String authorityId,
      {String period = 'all_time',
      DateTime? customStartDate,
      DateTime? customEndDate,
      String borderFilter = 'any_border'}) async {
    try {
      debugPrint(
          '🔍 Fetching detailed overstayed vehicles for authority: $authorityId');

      // Get authority currency
      final authorityResponse = await _supabase
          .from('authorities')
          .select('default_currency_code')
          .eq('id', authorityId)
          .single();

      final authorityCurrency =
          authorityResponse['default_currency_code'] as String? ?? 'USD';

      // Get overstayed passes with profile information
      final response = await _supabase
          .from('purchased_passes')
          .select('''
            *,
            profiles (
              id,
              full_name,
              email,
              profile_image_url,
              phone_number,
              address
            )
          ''')
          .eq('authority_id', authorityId)
          .lt('expires_at', DateTime.now().toIso8601String())
          .eq('current_status', 'checked_in');

      final allPasses =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      // Filter by time period
      final passes = _filterPassesByPeriod(
          allPasses, period, customStartDate, customEndDate);

      // Filter by border if specified
      final filteredPasses = borderFilter == 'any_border'
          ? passes
          : passes
              .where((p) =>
                  p.entryPointId == borderFilter ||
                  p.entryPointName == borderFilter ||
                  p.exitPointId == borderFilter ||
                  p.exitPointName == borderFilter)
              .toList();

      // Build detailed list with profile information
      final detailedList = <Map<String, dynamic>>[];

      for (final pass in filteredPasses) {
        // Find the corresponding raw data to get profile information
        final passData = response.firstWhere(
          (r) => r['id'] == pass.passId,
          orElse: () => <String, dynamic>{},
        );

        final profile = passData['profiles'] as Map<String, dynamic>?;
        final daysOverdue = DateTime.now().difference(pass.expiresAt).inDays;

        // Extract owner information from profile
        String ownerFullName = 'Owner Information Unavailable';
        String? ownerEmail;
        String? ownerPhone;
        String? ownerAddress;
        String? ownerProfileImage;

        if (profile != null) {
          ownerFullName = profile['full_name']?.toString() ?? 'Unknown Owner';
          ownerEmail = profile['email']?.toString();
          ownerPhone = profile['phone_number']?.toString();
          ownerAddress = profile['address']?.toString();
          ownerProfileImage = profile['profile_image_url']?.toString();
        }

        detailedList.add({
          'passId': pass.passId,
          'profileId': profile?['id']?.toString(), // Add the missing profileId
          'vehicleDescription': pass.vehicleDescription,
          'vehicleRegistrationNumber': pass.vehicleRegistrationNumber ?? 'N/A',
          'vehicleMake': pass.vehicleMake,
          'vehicleModel': pass.vehicleModel,
          'vehicleYear': pass.vehicleYear,
          'vehicleColor': pass.vehicleColor,
          'passDescription': pass.passDescription,
          'expiresAt': pass.expiresAt.toIso8601String(),
          'issuedAt': pass.issuedAt.toIso8601String(),
          'activationDate': pass.activationDate.toIso8601String(),
          'amount': pass.amount,
          'currency': pass.currency,
          'authorityCurrency': authorityCurrency,
          'daysOverdue': daysOverdue,
          'entryPointName': pass.entryPointName ?? 'Unknown',
          'exitPointName': pass.exitPointName,
          'authorityName': pass.authorityName ?? 'Unknown Authority',
          'countryName': pass.countryName ?? 'Unknown Country',
          'status': pass.status,
          'currentStatus': pass.currentStatus,
          'entryLimit': pass.entryLimit,
          'entriesRemaining': pass.entriesRemaining,
          'ownerFullName': ownerFullName,
          'ownerEmail': ownerEmail,
          'ownerPhone': ownerPhone,
          'ownerAddress': ownerAddress,
          'ownerProfileImage': ownerProfileImage,
        });
      }

      // Sort by days overdue (most critical first)
      detailedList.sort((a, b) =>
          (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int));

      debugPrint(
          '✅ Detailed overstayed vehicles fetched: ${detailedList.length} vehicles');

      return detailedList;
    } catch (e) {
      debugPrint('❌ Error fetching detailed overstayed vehicles: $e');
      rethrow;
    }
  }

  /// Get last recorded position for a pass from movement history
  static Future<Map<String, dynamic>?> getLastRecordedPosition(
      String passId) async {
    try {
      debugPrint('🔍 Fetching last recorded position for pass: $passId');

      // Validate passId
      if (passId.isEmpty || passId == 'null') {
        debugPrint('❌ Invalid passId: $passId');
        return null;
      }

      final response = await _supabase
          .from('pass_movements')
          .select('''
            *,
            border_officials (
              display_name,
              authority_profiles (
                authority_name
              )
            )
          ''')
          .eq('pass_id', passId)
          .order('created_at', ascending: false)
          .limit(1);

      debugPrint(
          '📊 Movement history response: ${response.length} records found');

      if (response.isEmpty) {
        debugPrint('No movement history found for pass: $passId');
        return null;
      }

      final movement = response.first;
      final borderOfficial =
          movement['border_officials'] as Map<String, dynamic>?;
      final authorityProfile =
          borderOfficial?['authority_profiles'] as Map<String, dynamic>?;

      final result = {
        'location': movement['location'] ?? 'Unknown Location',
        'timestamp': movement['created_at'],
        'scanPurpose': movement['scan_purpose'] ?? 'Unknown',
        'officerName': borderOfficial?['display_name'] ?? 'Unknown Officer',
        'authorityName':
            authorityProfile?['authority_name'] ?? 'Unknown Authority',
        'notes': movement['notes'],
      };

      debugPrint(
          '✅ Last position found: ${result['location']} at ${result['timestamp']}');
      return result;
    } catch (e) {
      debugPrint('❌ Error fetching last recorded position: $e');
      return null;
    }
  }

  /// Helper method to build full name from first and last name
  static String _buildFullName(String? firstName, String? lastName) {
    final parts = <String>[];
    if (firstName != null && firstName.isNotEmpty) parts.add(firstName);
    if (lastName != null && lastName.isNotEmpty) parts.add(lastName);
    return parts.isEmpty ? 'Unknown Owner' : parts.join(' ');
  }

  /// Get distribution tax collection efficiency analytics
  static Future<Map<String, dynamic>> getDistributionTaxCollectionEfficiency(
      String authorityId) async {
    try {
      debugPrint(
          '🔍 Analyzing distribution tax collection efficiency for authority: $authorityId');

      // Get all passes and border data
      final passesResponse = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId);

      final passes =
          passesResponse.map((json) => PurchasedPass.fromJson(json)).toList();

      // Get borders for this authority
      final bordersResponse = await _supabase
          .from('borders')
          .select('id, name, border_types(label)')
          .eq('authority_id', authorityId)
          .eq('is_active', true);

      // Calculate collection efficiency by border/entry point
      final borderEfficiency = <String, Map<String, dynamic>>{};
      final borderRevenue = <String, double>{};
      final borderPassCount = <String, int>{};

      // Analyze entry points
      for (final pass in passes) {
        final entryPoint = pass.entryPointName ?? 'Unknown Entry Point';

        borderRevenue[entryPoint] =
            (borderRevenue[entryPoint] ?? 0.0) + pass.amount;
        borderPassCount[entryPoint] = (borderPassCount[entryPoint] ?? 0) + 1;

        // Calculate efficiency metrics per border
        if (!borderEfficiency.containsKey(entryPoint)) {
          borderEfficiency[entryPoint] = {
            'total_revenue': 0.0,
            'total_passes': 0,
            'active_passes': 0,
            'expired_passes': 0,
            'compliance_rate': 0.0,
            'collection_rate': 0.0,
            'average_pass_value': 0.0,
          };
        }

        final borderData = borderEfficiency[entryPoint]!;
        borderData['total_revenue'] =
            (borderData['total_revenue'] as double) + pass.amount;
        borderData['total_passes'] = (borderData['total_passes'] as int) + 1;

        if (pass.isExpired) {
          borderData['expired_passes'] =
              (borderData['expired_passes'] as int) + 1;
        } else if (pass.status == 'active') {
          borderData['active_passes'] =
              (borderData['active_passes'] as int) + 1;
        }
      }

      // Calculate final efficiency metrics
      for (final entry in borderEfficiency.entries) {
        final data = entry.value;
        final totalPasses = data['total_passes'] as int;
        final totalRevenue = data['total_revenue'] as double;
        final expiredPasses = data['expired_passes'] as int;

        if (totalPasses > 0) {
          data['compliance_rate'] =
              ((totalPasses - expiredPasses) / totalPasses * 100);
          data['collection_rate'] =
              100.0; // Assuming all passes are paid upfront
          data['average_pass_value'] = totalRevenue / totalPasses;
        }
      }

      // Calculate overall distribution metrics
      final totalRevenue = passes.fold<double>(0.0, (sum, p) => sum + p.amount);
      final totalPasses = passes.length;

      // Distribution by border type
      final borderTypeRevenue = <String, double>{};
      final borderTypeCount = <String, int>{};

      for (final border in bordersResponse) {
        final borderName = border['name'] as String;
        final borderType =
            border['border_types']?['label'] as String? ?? 'Unknown';

        final revenue = borderRevenue[borderName] ?? 0.0;
        final count = borderPassCount[borderName] ?? 0;

        borderTypeRevenue[borderType] =
            (borderTypeRevenue[borderType] ?? 0.0) + revenue;
        borderTypeCount[borderType] =
            (borderTypeCount[borderType] ?? 0) + count;
      }

      // Top performing borders
      final topBorders = borderEfficiency.entries
          .map((e) => {
                'name': e.key,
                'revenue': e.value['total_revenue'],
                'passes': e.value['total_passes'],
                'compliance_rate': e.value['compliance_rate'],
                'average_value': e.value['average_pass_value'],
              })
          .toList()
        ..sort((a, b) =>
            (b['revenue'] as double).compareTo(a['revenue'] as double));

      // Calculate distribution efficiency score
      final averageComplianceRate = borderEfficiency.values.isEmpty
          ? 0.0
          : borderEfficiency.values.fold<double>(0.0,
                  (sum, data) => sum + (data['compliance_rate'] as double)) /
              borderEfficiency.values.length;

      final distributionScore =
          (averageComplianceRate * 0.6 + (totalPasses > 0 ? 100.0 : 0.0) * 0.4)
              .clamp(0.0, 100.0);

      debugPrint('✅ Distribution efficiency analysis complete');

      return {
        'overall_efficiency_score': distributionScore,
        'total_revenue': totalRevenue,
        'total_passes': totalPasses,
        'average_compliance_rate': averageComplianceRate,
        'border_efficiency': borderEfficiency,
        'border_type_distribution': {
          'revenue': borderTypeRevenue,
          'count': borderTypeCount,
        },
        'top_performing_borders': topBorders.take(10).toList(),
        'underperforming_borders': topBorders.reversed.take(5).toList(),
        'recommendations': _generateDistributionRecommendations(
            borderEfficiency, averageComplianceRate),
      };
    } catch (e) {
      debugPrint('❌ Error analyzing distribution efficiency: $e');
      throw Exception(
          'Failed to analyze distribution tax collection efficiency: $e');
    }
  }

  /// Generate recommendations for distribution efficiency
  static List<Map<String, dynamic>> _generateDistributionRecommendations(
    Map<String, Map<String, dynamic>> borderEfficiency,
    double averageComplianceRate,
  ) {
    final recommendations = <Map<String, dynamic>>[];

    // Find borders with low compliance rates
    final lowComplianceBorders = borderEfficiency.entries
        .where((e) => (e.value['compliance_rate'] as double) < 80.0)
        .toList();

    if (lowComplianceBorders.isNotEmpty) {
      recommendations.add({
        'type': 'compliance',
        'priority': 'high',
        'title': 'Improve Border Compliance',
        'description':
            '${lowComplianceBorders.length} borders have compliance rates below 80%',
        'action':
            'Increase enforcement and monitoring at underperforming borders',
        'affected_borders': lowComplianceBorders.map((e) => e.key).toList(),
      });
    }

    // Find borders with low revenue per pass
    final lowRevenueBorders = borderEfficiency.entries
        .where((e) => (e.value['average_pass_value'] as double) < 50.0)
        .toList();

    if (lowRevenueBorders.isNotEmpty) {
      recommendations.add({
        'type': 'revenue',
        'priority': 'medium',
        'title': 'Review Pricing Strategy',
        'description':
            '${lowRevenueBorders.length} borders have low average pass values',
        'action':
            'Consider adjusting tax rates or pass types for these borders',
        'affected_borders': lowRevenueBorders.map((e) => e.key).toList(),
      });
    }

    if (averageComplianceRate < 90.0) {
      recommendations.add({
        'type': 'system',
        'priority': 'medium',
        'title': 'Enhance Overall Compliance',
        'description': 'Overall compliance rate is below optimal levels',
        'action': 'Implement automated compliance monitoring and alerts',
      });
    }

    return recommendations;
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
