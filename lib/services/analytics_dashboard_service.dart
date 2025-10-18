import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'business_intelligence_service.dart';
import 'fraud_detection_service.dart';

/// Comprehensive Analytics Dashboard Service
/// Provides unified analytics data for executive dashboards
class AnalyticsDashboardService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get comprehensive dashboard data for an authority
  static Future<Map<String, dynamic>> getComprehensiveDashboardData(
      String authorityId) async {
    try {
      debugPrint(
          '🔍 Fetching comprehensive dashboard data for authority: $authorityId');

      // Fetch all analytics data in parallel for better performance
      final futures = await Future.wait([
        BusinessIntelligenceService.getDashboardData(authorityId),
        BusinessIntelligenceService.getRevenueAnalyticsData(authorityId),
        BusinessIntelligenceService.getDistributionTaxCollectionEfficiency(
            authorityId),
        FraudDetectionService.detectSuspiciousActivity(authorityId),
        _getPaymentAnalytics(authorityId),
        _getOperationalMetrics(authorityId),
      ]);

      final dashboardData = futures[0] as Map<String, dynamic>;
      final revenueData = futures[1] as Map<String, dynamic>;
      final distributionData = futures[2] as Map<String, dynamic>;
      final fraudData = futures[3] as Map<String, dynamic>;
      final paymentData = futures[4] as Map<String, dynamic>;
      final operationalData = futures[5] as Map<String, dynamic>;

      // Calculate key performance indicators
      final kpis = _calculateKPIs(
          dashboardData, revenueData, distributionData, fraudData);

      // Generate executive summary
      final executiveSummary = _generateExecutiveSummary(
          dashboardData, revenueData, distributionData, fraudData, paymentData);

      debugPrint('✅ Comprehensive dashboard data compiled successfully');

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'authority_id': authorityId,

        // Key Performance Indicators
        'kpis': kpis,

        // Executive Summary
        'executive_summary': executiveSummary,

        // Core Metrics
        'dashboard_metrics': dashboardData,
        'revenue_analytics': revenueData,
        'distribution_efficiency': distributionData,
        'fraud_detection': fraudData,
        'payment_analytics': paymentData,
        'operational_metrics': operationalData,

        // Alerts and Recommendations
        'critical_alerts': _getCriticalAlerts(fraudData, distributionData),
        'recommendations':
            _getConsolidatedRecommendations(distributionData, fraudData),

        // Trends and Forecasting
        'trends': _analyzeTrends(revenueData, dashboardData),
        'forecasts': _generateForecasts(revenueData),
      };
    } catch (e) {
      debugPrint('❌ Error fetching comprehensive dashboard data: $e');
      throw Exception('Failed to fetch comprehensive dashboard data: $e');
    }
  }

  /// Get payment analytics for the authority
  static Future<Map<String, dynamic>> _getPaymentAnalytics(
      String authorityId) async {
    try {
      // Get payment-related data from purchased passes
      final response = await _supabase
          .from('purchased_passes')
          .select('amount, currency, issued_at, status, payment_provider')
          .eq('authority_id', authorityId);

      final passes = response as List<dynamic>;

      // Calculate payment method distribution
      final paymentMethods = <String, int>{};
      final paymentRevenue = <String, double>{};
      var totalTransactions = 0;
      var successfulTransactions = 0;
      var failedTransactions = 0;

      for (final pass in passes) {
        final provider = pass['payment_provider']?.toString() ?? 'unknown';
        final amount = (pass['amount'] as num?)?.toDouble() ?? 0.0;
        final status = pass['status']?.toString() ?? 'unknown';

        paymentMethods[provider] = (paymentMethods[provider] ?? 0) + 1;
        paymentRevenue[provider] = (paymentRevenue[provider] ?? 0.0) + amount;

        totalTransactions++;
        if (status == 'active' || status == 'expired') {
          successfulTransactions++;
        } else {
          failedTransactions++;
        }
      }

      final successRate = totalTransactions > 0
          ? (successfulTransactions / totalTransactions * 100)
          : 0.0;

      return {
        'total_transactions': totalTransactions,
        'successful_transactions': successfulTransactions,
        'failed_transactions': failedTransactions,
        'success_rate': successRate,
        'payment_methods': paymentMethods,
        'payment_revenue': paymentRevenue,
        'average_transaction_value': totalTransactions > 0
            ? paymentRevenue.values.fold<double>(0.0, (sum, val) => sum + val) /
                totalTransactions
            : 0.0,
      };
    } catch (e) {
      debugPrint('❌ Error getting payment analytics: $e');
      return {
        'total_transactions': 0,
        'successful_transactions': 0,
        'failed_transactions': 0,
        'success_rate': 0.0,
        'payment_methods': <String, int>{},
        'payment_revenue': <String, double>{},
        'average_transaction_value': 0.0,
      };
    }
  }

  /// Get operational metrics
  static Future<Map<String, dynamic>> _getOperationalMetrics(
      String authorityId) async {
    try {
      // Get border and staff data
      final bordersResponse = await _supabase
          .from('borders')
          .select('id, name')
          .eq('authority_id', authorityId)
          .eq('is_active', true);

      final staffResponse = await _supabase
          .from('profile_roles')
          .select('profile_id, roles!inner(name)')
          .eq('authority_id', authorityId)
          .eq('is_active', true);

      final borders = bordersResponse as List<dynamic>;
      final staff = staffResponse as List<dynamic>;

      // Count staff by role
      final staffByRole = <String, int>{};
      for (final member in staff) {
        final role = member['roles']['name'] as String;
        staffByRole[role] = (staffByRole[role] ?? 0) + 1;
      }

      // Calculate operational efficiency
      final totalBorders = borders.length;
      final totalStaff = staff.length;
      final borderManagerCount = staffByRole['border_manager'] ?? 0;
      final borderOfficialCount = staffByRole['border_official'] ?? 0;

      final staffToBorderRatio =
          totalBorders > 0 ? totalStaff / totalBorders : 0.0;
      final managementRatio =
          totalStaff > 0 ? borderManagerCount / totalStaff : 0.0;

      return {
        'total_borders': totalBorders,
        'total_staff': totalStaff,
        'staff_by_role': staffByRole,
        'staff_to_border_ratio': staffToBorderRatio,
        'management_ratio': managementRatio,
        'operational_efficiency_score': _calculateOperationalEfficiency(
            totalBorders, totalStaff, borderManagerCount, borderOfficialCount),
      };
    } catch (e) {
      debugPrint('❌ Error getting operational metrics: $e');
      return {
        'total_borders': 0,
        'total_staff': 0,
        'staff_by_role': <String, int>{},
        'staff_to_border_ratio': 0.0,
        'management_ratio': 0.0,
        'operational_efficiency_score': 0.0,
      };
    }
  }

  /// Calculate operational efficiency score
  static double _calculateOperationalEfficiency(int totalBorders,
      int totalStaff, int borderManagerCount, int borderOfficialCount) {
    if (totalBorders == 0 || totalStaff == 0) return 0.0;

    // Ideal ratios (configurable)
    const idealStaffPerBorder = 3.0;
    const idealManagerRatio = 0.2; // 20% managers

    final staffRatioScore =
        (totalStaff / totalBorders / idealStaffPerBorder * 100)
            .clamp(0.0, 100.0);
    final managerRatioScore = totalStaff > 0
        ? ((borderManagerCount / totalStaff) / idealManagerRatio * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    return (staffRatioScore * 0.6 + managerRatioScore * 0.4);
  }

  /// Calculate Key Performance Indicators
  static Map<String, dynamic> _calculateKPIs(
    Map<String, dynamic> dashboardData,
    Map<String, dynamic> revenueData,
    Map<String, dynamic> distributionData,
    Map<String, dynamic> fraudData,
  ) {
    return {
      'revenue_growth': revenueData['revenueGrowth'] ?? 0.0,
      'compliance_rate': dashboardData['complianceRate'] ?? 0.0,
      'collection_efficiency': revenueData['collectionEfficiency'] ?? 0.0,
      'distribution_efficiency':
          distributionData['overall_efficiency_score'] ?? 0.0,
      'fraud_risk_score': fraudData['risk_score'] ?? 0,
      'total_revenue': dashboardData['totalRevenue'] ?? 0.0,
      'active_passes': dashboardData['activePasses'] ?? 0,
      'border_crossings': dashboardData['borderCrossings'] ?? 0,
    };
  }

  /// Generate executive summary
  static Map<String, dynamic> _generateExecutiveSummary(
    Map<String, dynamic> dashboardData,
    Map<String, dynamic> revenueData,
    Map<String, dynamic> distributionData,
    Map<String, dynamic> fraudData,
    Map<String, dynamic> paymentData,
  ) {
    final totalRevenue = dashboardData['totalRevenue'] as double? ?? 0.0;
    final revenueGrowth = revenueData['revenueGrowth'] as double? ?? 0.0;
    final complianceRate = dashboardData['complianceRate'] as double? ?? 0.0;
    final fraudAlerts = fraudData['total_alerts'] as int? ?? 0;

    String performanceStatus;
    if (complianceRate >= 95 && revenueGrowth >= 10) {
      performanceStatus = 'excellent';
    } else if (complianceRate >= 85 && revenueGrowth >= 5) {
      performanceStatus = 'good';
    } else if (complianceRate >= 75 && revenueGrowth >= 0) {
      performanceStatus = 'fair';
    } else {
      performanceStatus = 'needs_attention';
    }

    return {
      'performance_status': performanceStatus,
      'key_highlights': [
        'Total revenue: \$${totalRevenue.toStringAsFixed(2)}',
        'Revenue growth: ${revenueGrowth.toStringAsFixed(1)}%',
        'Compliance rate: ${complianceRate.toStringAsFixed(1)}%',
        'Fraud alerts: $fraudAlerts',
      ],
      'critical_issues': _identifyCriticalIssues(dashboardData, fraudData),
      'success_metrics': _identifySuccessMetrics(revenueData, distributionData),
    };
  }

  /// Identify critical issues requiring immediate attention
  static List<String> _identifyCriticalIssues(
    Map<String, dynamic> dashboardData,
    Map<String, dynamic> fraudData,
  ) {
    final issues = <String>[];

    final complianceRate = dashboardData['complianceRate'] as double? ?? 0.0;
    final overstayedVehicles = dashboardData['overstayedVehicles'] as int? ?? 0;
    final fraudAlerts = fraudData['total_alerts'] as int? ?? 0;
    final riskScore = fraudData['risk_score'] as int? ?? 0;

    if (complianceRate < 80) {
      issues.add(
          'Low compliance rate (${complianceRate.toStringAsFixed(1)}%) requires immediate attention');
    }

    if (overstayedVehicles > 10) {
      issues.add('$overstayedVehicles vehicles are overstaying their passes');
    }

    if (riskScore > 50) {
      issues.add('High fraud risk score ($riskScore) detected');
    }

    if (fraudAlerts > 5) {
      issues.add('$fraudAlerts fraud alerts require investigation');
    }

    return issues;
  }

  /// Identify success metrics and positive trends
  static List<String> _identifySuccessMetrics(
    Map<String, dynamic> revenueData,
    Map<String, dynamic> distributionData,
  ) {
    final successes = <String>[];

    final revenueGrowth = revenueData['revenueGrowth'] as double? ?? 0.0;
    final collectionEfficiency =
        revenueData['collectionEfficiency'] as double? ?? 0.0;
    final distributionScore =
        distributionData['overall_efficiency_score'] as double? ?? 0.0;

    if (revenueGrowth > 10) {
      successes
          .add('Strong revenue growth of ${revenueGrowth.toStringAsFixed(1)}%');
    }

    if (collectionEfficiency > 95) {
      successes.add(
          'Excellent collection efficiency (${collectionEfficiency.toStringAsFixed(1)}%)');
    }

    if (distributionScore > 85) {
      successes.add(
          'High distribution efficiency score (${distributionScore.toStringAsFixed(1)})');
    }

    return successes;
  }

  /// Get critical alerts that need immediate attention
  static List<Map<String, dynamic>> _getCriticalAlerts(
    Map<String, dynamic> fraudData,
    Map<String, dynamic> distributionData,
  ) {
    final alerts = <Map<String, dynamic>>[];

    // Add high-priority fraud alerts
    final suspiciousActivities =
        fraudData['suspicious_activities'] as List<dynamic>? ?? [];
    for (final activity in suspiciousActivities) {
      if (activity['severity'] == 'high') {
        alerts.add({
          'type': 'fraud',
          'severity': 'high',
          'title': activity['description'],
          'details': activity,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    // Add distribution efficiency alerts
    final distributionRecommendations =
        distributionData['recommendations'] as List<dynamic>? ?? [];
    for (final recommendation in distributionRecommendations) {
      if (recommendation['priority'] == 'high') {
        alerts.add({
          'type': 'distribution',
          'severity': 'high',
          'title': recommendation['title'],
          'details': recommendation,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    return alerts;
  }

  /// Get consolidated recommendations from all services
  static List<Map<String, dynamic>> _getConsolidatedRecommendations(
    Map<String, dynamic> distributionData,
    Map<String, dynamic> fraudData,
  ) {
    final recommendations = <Map<String, dynamic>>[];

    // Add distribution recommendations
    final distributionRecs =
        distributionData['recommendations'] as List<dynamic>? ?? [];
    recommendations.addAll(distributionRecs.cast<Map<String, dynamic>>());

    // Add fraud recommendations
    final fraudRecs = fraudData['recommendations'] as List<dynamic>? ?? [];
    recommendations.addAll(fraudRecs.cast<Map<String, dynamic>>());

    // Sort by priority
    recommendations.sort((a, b) {
      const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final aPriority = priorityOrder[a['priority']] ?? 3;
      final bPriority = priorityOrder[b['priority']] ?? 3;
      return aPriority.compareTo(bPriority);
    });

    return recommendations;
  }

  /// Analyze trends across different metrics
  static Map<String, dynamic> _analyzeTrends(
    Map<String, dynamic> revenueData,
    Map<String, dynamic> dashboardData,
  ) {
    final monthlyTrends = revenueData['monthlyTrends'] as List<dynamic>? ?? [];

    if (monthlyTrends.length < 2) {
      return {
        'revenue_trend': 'insufficient_data',
        'growth_trend': 'insufficient_data',
        'trend_analysis': 'Need more data points for trend analysis',
      };
    }

    // Calculate trend direction
    final recentRevenue = monthlyTrends.last['revenue'] as double? ?? 0.0;
    final previousRevenue =
        monthlyTrends[monthlyTrends.length - 2]['revenue'] as double? ?? 0.0;

    String revenueTrend;
    if (recentRevenue > previousRevenue * 1.1) {
      revenueTrend = 'strong_growth';
    } else if (recentRevenue > previousRevenue) {
      revenueTrend = 'moderate_growth';
    } else if (recentRevenue > previousRevenue * 0.9) {
      revenueTrend = 'stable';
    } else {
      revenueTrend = 'declining';
    }

    return {
      'revenue_trend': revenueTrend,
      'growth_trend': revenueData['revenueGrowth'] ?? 0.0,
      'trend_analysis': _generateTrendAnalysis(revenueTrend, monthlyTrends),
    };
  }

  /// Generate trend analysis text
  static String _generateTrendAnalysis(
      String revenueTrend, List<dynamic> monthlyTrends) {
    switch (revenueTrend) {
      case 'strong_growth':
        return 'Revenue is showing strong upward momentum with consistent month-over-month growth.';
      case 'moderate_growth':
        return 'Revenue is growing steadily with positive trends across recent months.';
      case 'stable':
        return 'Revenue remains stable with minor fluctuations within normal ranges.';
      case 'declining':
        return 'Revenue is showing a declining trend that requires attention and intervention.';
      default:
        return 'Trend analysis requires more historical data points.';
    }
  }

  /// Generate revenue forecasts
  static Map<String, dynamic> _generateForecasts(
      Map<String, dynamic> revenueData) {
    final monthlyTrends = revenueData['monthlyTrends'] as List<dynamic>? ?? [];
    final yearlyProjection = revenueData['yearlyProjection'] as double? ?? 0.0;
    final revenueGrowth = revenueData['revenueGrowth'] as double? ?? 0.0;

    if (monthlyTrends.isEmpty) {
      return {
        'next_month_forecast': 0.0,
        'quarterly_forecast': 0.0,
        'yearly_projection': yearlyProjection,
        'confidence_level': 'low',
      };
    }

    final recentRevenue = monthlyTrends.last['revenue'] as double? ?? 0.0;
    final growthMultiplier = 1 + (revenueGrowth / 100);

    return {
      'next_month_forecast': recentRevenue * growthMultiplier,
      'quarterly_forecast': recentRevenue * growthMultiplier * 3,
      'yearly_projection': yearlyProjection,
      'confidence_level': monthlyTrends.length >= 6 ? 'high' : 'medium',
    };
  }
}
