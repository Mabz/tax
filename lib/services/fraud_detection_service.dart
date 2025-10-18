import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';

class FraudDetectionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Detect suspicious activity patterns for an authority
  static Future<Map<String, dynamic>> detectSuspiciousActivity(
      String authorityId) async {
    try {
      debugPrint(
          '🔍 Analyzing suspicious activity for authority: $authorityId');

      // Get all passes for analysis
      final response = await _supabase
          .from('purchased_passes')
          .select('*')
          .eq('authority_id', authorityId);

      final passes =
          response.map((json) => PurchasedPass.fromJson(json)).toList();

      final suspiciousActivities = <Map<String, dynamic>>[];
      final alerts = <String, int>{};

      // 1. Detect multiple passes for same vehicle in short time
      final vehiclePassMap = <String, List<PurchasedPass>>{};
      for (final pass in passes) {
        if (pass.vehicleRegistrationNumber != null &&
            pass.vehicleRegistrationNumber!.isNotEmpty) {
          vehiclePassMap
              .putIfAbsent(pass.vehicleRegistrationNumber!, () => [])
              .add(pass);
        }
      }

      for (final entry in vehiclePassMap.entries) {
        final vehiclePasses = entry.value;
        if (vehiclePasses.length > 1) {
          // Check for passes issued within 24 hours
          vehiclePasses.sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
          for (int i = 1; i < vehiclePasses.length; i++) {
            final timeDiff = vehiclePasses[i]
                .issuedAt
                .difference(vehiclePasses[i - 1].issuedAt);
            if (timeDiff.inHours < 24) {
              suspiciousActivities.add({
                'type': 'duplicate_vehicle_passes',
                'severity': 'medium',
                'description':
                    'Multiple passes issued for same vehicle within 24 hours',
                'vehicle': entry.key,
                'pass_count': vehiclePasses.length,
                'time_difference_hours': timeDiff.inHours,
                'passes': vehiclePasses.map((p) => p.passId).toList(),
              });
              alerts['duplicate_vehicle_passes'] =
                  (alerts['duplicate_vehicle_passes'] ?? 0) + 1;
            }
          }
        }
      }

      // 2. Detect expired passes still active (overstaying)
      final overstayingPasses = passes
          .where((p) => p.isExpired && p.currentStatus == 'checked_in')
          .toList();

      for (final pass in overstayingPasses) {
        final daysOverdue = DateTime.now().difference(pass.expiresAt).inDays;
        suspiciousActivities.add({
          'type': 'overstaying_vehicle',
          'severity': daysOverdue > 30
              ? 'high'
              : daysOverdue > 7
                  ? 'medium'
                  : 'low',
          'description': 'Vehicle overstaying with expired pass',
          'vehicle': pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
          'pass_id': pass.passId,
          'days_overdue': daysOverdue,
          'amount_at_risk': pass.amount,
          'currency': pass.currency,
        });
      }
      alerts['overstaying_vehicles'] = overstayingPasses.length;

      // 3. Detect unusual pass usage patterns
      final unusualUsagePasses = passes
          .where((p) => p.entriesRemaining == 0 && p.currentStatus == 'unused')
          .toList();

      for (final pass in unusualUsagePasses) {
        suspiciousActivities.add({
          'type': 'unused_consumed_pass',
          'severity': 'low',
          'description': 'Pass marked as consumed but never used',
          'vehicle': pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
          'pass_id': pass.passId,
          'amount': pass.amount,
          'currency': pass.currency,
        });
      }
      alerts['unusual_usage'] = unusualUsagePasses.length;

      // 4. Detect high-value transactions from new users
      final highValuePasses = passes.where((p) => p.amount > 1000).toList();
      for (final pass in highValuePasses) {
        // Check if user has other passes (not a new user)
        final userPassCount =
            passes.where((p) => p.profileId == pass.profileId).length;
        if (userPassCount == 1) {
          suspiciousActivities.add({
            'type': 'high_value_new_user',
            'severity': 'medium',
            'description': 'High-value pass purchased by new user',
            'vehicle':
                pass.vehicleRegistrationNumber ?? pass.vehicleDescription,
            'pass_id': pass.passId,
            'amount': pass.amount,
            'currency': pass.currency,
            'profile_id': pass.profileId,
          });
          alerts['high_value_new_user'] =
              (alerts['high_value_new_user'] ?? 0) + 1;
        }
      }

      // 5. Detect rapid consecutive purchases
      final profilePassMap = <String, List<PurchasedPass>>{};
      for (final pass in passes) {
        if (pass.profileId != null) {
          profilePassMap.putIfAbsent(pass.profileId!, () => []).add(pass);
        }
      }

      for (final entry in profilePassMap.entries) {
        final userPasses = entry.value;
        if (userPasses.length >= 3) {
          userPasses.sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
          // Check for 3+ passes within 1 hour
          for (int i = 2; i < userPasses.length; i++) {
            final timeDiff =
                userPasses[i].issuedAt.difference(userPasses[i - 2].issuedAt);
            if (timeDiff.inHours < 1) {
              suspiciousActivities.add({
                'type': 'rapid_purchases',
                'severity': 'high',
                'description': 'Multiple passes purchased rapidly by same user',
                'profile_id': entry.key,
                'pass_count': 3,
                'time_window_minutes': timeDiff.inMinutes,
                'total_amount': userPasses
                    .sublist(i - 2, i + 1)
                    .fold<double>(0, (sum, p) => sum + p.amount),
              });
              alerts['rapid_purchases'] = (alerts['rapid_purchases'] ?? 0) + 1;
              break;
            }
          }
        }
      }

      // Calculate risk scores
      final totalAlerts =
          alerts.values.fold<int>(0, (sum, count) => sum + count);
      final highSeverityCount =
          suspiciousActivities.where((a) => a['severity'] == 'high').length;
      final mediumSeverityCount =
          suspiciousActivities.where((a) => a['severity'] == 'medium').length;

      final riskScore = (highSeverityCount * 10 +
              mediumSeverityCount * 5 +
              (totalAlerts - highSeverityCount - mediumSeverityCount) * 1)
          .clamp(0, 100);

      debugPrint(
          '✅ Fraud analysis complete: ${suspiciousActivities.length} suspicious activities found');

      return {
        'total_alerts': totalAlerts,
        'risk_score': riskScore,
        'alert_breakdown': alerts,
        'suspicious_activities': suspiciousActivities,
        'recommendations': _generateRecommendations(alerts, riskScore),
        'analysis_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error detecting suspicious activity: $e');
      throw Exception('Failed to analyze suspicious activity: $e');
    }
  }

  /// Generate recommendations based on detected patterns
  static List<Map<String, dynamic>> _generateRecommendations(
      Map<String, int> alerts, int riskScore) {
    final recommendations = <Map<String, dynamic>>[];

    if (alerts['overstaying_vehicles'] != null &&
        alerts['overstaying_vehicles']! > 0) {
      recommendations.add({
        'type': 'enforcement',
        'priority': 'high',
        'title': 'Address Overstaying Vehicles',
        'description':
            'Contact ${alerts['overstaying_vehicles']} vehicles that have overstayed their passes',
        'action': 'Send notifications and consider penalties',
      });
    }

    if (alerts['duplicate_vehicle_passes'] != null &&
        alerts['duplicate_vehicle_passes']! > 0) {
      recommendations.add({
        'type': 'verification',
        'priority': 'medium',
        'title': 'Verify Duplicate Vehicle Passes',
        'description':
            'Review vehicles with multiple passes issued within 24 hours',
        'action': 'Implement vehicle verification checks',
      });
    }

    if (alerts['rapid_purchases'] != null && alerts['rapid_purchases']! > 0) {
      recommendations.add({
        'type': 'security',
        'priority': 'high',
        'title': 'Investigate Rapid Purchases',
        'description':
            'Users making multiple purchases in short timeframes may indicate fraud',
        'action': 'Implement purchase rate limiting',
      });
    }

    if (riskScore > 50) {
      recommendations.add({
        'type': 'system',
        'priority': 'high',
        'title': 'Enhanced Monitoring Required',
        'description':
            'High risk score indicates need for increased surveillance',
        'action': 'Enable real-time fraud monitoring alerts',
      });
    }

    return recommendations;
  }

  /// Get fraud statistics for dashboard
  static Future<Map<String, dynamic>> getFraudStatistics(
      String authorityId) async {
    try {
      final fraudData = await detectSuspiciousActivity(authorityId);

      return {
        'total_alerts': fraudData['total_alerts'],
        'risk_score': fraudData['risk_score'],
        'high_priority_alerts': fraudData['suspicious_activities']
            .where((a) => a['severity'] == 'high')
            .length,
        'medium_priority_alerts': fraudData['suspicious_activities']
            .where((a) => a['severity'] == 'medium')
            .length,
        'low_priority_alerts': fraudData['suspicious_activities']
            .where((a) => a['severity'] == 'low')
            .length,
        'recommendations_count': fraudData['recommendations'].length,
      };
    } catch (e) {
      return {
        'total_alerts': 0,
        'risk_score': 0,
        'high_priority_alerts': 0,
        'medium_priority_alerts': 0,
        'low_priority_alerts': 0,
        'recommendations_count': 0,
      };
    }
  }
}
