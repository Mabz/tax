import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/audit_log.dart';
import '../services/role_service.dart';

/// Paginated audit logs response
class AuditLogsResponse {
  final List<AuditLog> logs;
  final int totalCount;
  final bool hasMore;

  AuditLogsResponse({
    required this.logs,
    required this.totalCount,
    required this.hasMore,
  });
}

/// Service for managing audit logs
class AuditService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get audit logs for a specific country using the basic function
  static Future<List<AuditLog>> getAuditLogsByCountry(String countryId) async {
    try {
      debugPrint('🔍 Fetching audit logs for country: $countryId');

      // Try the database function first
      try {
        final response =
            await _supabase.rpc('get_audit_logs_by_country', params: {
          'target_country_id': countryId,
        });

        debugPrint('✅ Fetched ${response.length} audit logs using function');
        return response
            .map<AuditLog>((json) => AuditLog.fromJson(json))
            .toList();
      } catch (functionError) {
        debugPrint(
            '⚠️ Function call failed, trying direct table query: $functionError');

        // Fall back to direct table query if function doesn't exist
        final response = await _supabase
            .from(AppConstants.tableAuditLogs)
            .select()
            .order(AppConstants.fieldCreatedAt, ascending: false);

        debugPrint(
            '✅ Fetched ${response.length} audit logs using direct query');

        // Filter by country in memory
        final allLogs =
            response.map<AuditLog>((json) => AuditLog.fromJson(json)).toList();
        final filteredLogs = allLogs.where((log) {
          final metadata = log.metadata;
          if (metadata == null) return false;
          final logCountryId = metadata['country_id'] as String?;
          return logCountryId == countryId;
        }).toList();

        debugPrint(
            '✅ Filtered to ${filteredLogs.length} logs for country $countryId');
        return filteredLogs;
      }
    } catch (e) {
      debugPrint('❌ Error fetching audit logs by country: $e');
      rethrow;
    }
  }

  /// Get paginated audit logs with search support
  static Future<AuditLogsResponse> getAuditLogsPaginated({
    String? countryId,
    Map<String, dynamic>? searchMetadata,
    String? searchAction,
    int limit = 50,
    int offset = 0,
    String orderBy = 'created_at',
    String orderDirection = 'DESC',
  }) async {
    try {
      debugPrint(
          '🔍 Fetching paginated audit logs - Country: $countryId, Limit: $limit, Offset: $offset');

      // If we have the paginated function, use it, otherwise fall back to basic function
      try {
        final response =
            await _supabase.rpc('get_audit_logs_paginated', params: {
          'target_country_id': countryId,
          'search_metadata': searchMetadata,
          'search_action': searchAction,
          'limit_count': limit,
          'offset_count': offset,
          'order_by': orderBy,
          'order_direction': orderDirection,
        });

        debugPrint('✅ Fetched ${response.length} audit logs (paginated)');

        final logs = <AuditLog>[];
        int totalCount = 0;

        for (final item in response) {
          logs.add(AuditLog.fromJson(item));
          totalCount = item['total_count'] ?? 0;
        }

        final hasMore = (offset + limit) < totalCount;

        return AuditLogsResponse(
          logs: logs,
          totalCount: totalCount,
          hasMore: hasMore,
        );
      } catch (e) {
        debugPrint(
            '⚠️ Paginated function not available, falling back to basic function: $e');

        // Fall back to basic function if paginated one doesn't exist
        if (countryId != null) {
          final logs = await getAuditLogsByCountry(countryId);

          // Apply basic filtering and pagination in memory
          var filteredLogs = logs;

          if (searchAction != null) {
            filteredLogs = filteredLogs
                .where((log) => log.action
                    .toLowerCase()
                    .contains(searchAction.toLowerCase()))
                .toList();
          }

          final totalCount = filteredLogs.length;
          final startIndex = offset;
          final endIndex = (startIndex + limit).clamp(0, totalCount);
          final paginatedLogs = filteredLogs.sublist(startIndex, endIndex);

          return AuditLogsResponse(
            logs: paginatedLogs,
            totalCount: totalCount,
            hasMore: endIndex < totalCount,
          );
        } else {
          // For global logs, use the basic table query
          final response = await _supabase
              .from(AppConstants.tableAuditLogs)
              .select()
              .order(AppConstants.fieldCreatedAt, ascending: false)
              .range(offset, offset + limit - 1);

          final logs = response
              .map<AuditLog>((json) => AuditLog.fromJson(json))
              .toList();

          return AuditLogsResponse(
            logs: logs,
            totalCount: logs.length, // This is approximate
            hasMore: logs.length == limit,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching paginated audit logs: $e');
      rethrow;
    }
  }

  /// Advanced search with JSONB path queries
  static Future<AuditLogsResponse> searchAuditLogsAdvanced({
    String? jsonbPath,
    String? jsonbValue,
    String jsonbOperator = '=',
    String? countryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      debugPrint(
          '🔍 Advanced audit logs search - Path: $jsonbPath, Value: $jsonbValue');

      final response =
          await _supabase.rpc('search_audit_logs_advanced', params: {
        'jsonb_path': jsonbPath,
        'jsonb_value': jsonbValue,
        'jsonb_operator': jsonbOperator,
        'target_country_id': countryId,
        'date_from': dateFrom?.toIso8601String(),
        'date_to': dateTo?.toIso8601String(),
        'limit_count': limit,
        'offset_count': offset,
      });

      debugPrint('✅ Advanced search returned ${response.length} audit logs');

      final logs = <AuditLog>[];
      int totalCount = 0;

      for (final item in response) {
        logs.add(AuditLog.fromJson(item));
        totalCount = item['total_count'] ?? 0;
      }

      final hasMore = (offset + limit) < totalCount;

      return AuditLogsResponse(
        logs: logs,
        totalCount: totalCount,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('❌ Error in advanced audit logs search: $e');
      rethrow;
    }
  }

  /// Get all audit logs (for superusers)
  static Future<List<AuditLog>> getAllAuditLogs({
    int limit = 100,
  }) async {
    try {
      debugPrint('🔍 Fetching all audit logs');

      final response = await _supabase
          .from(AppConstants.tableAuditLogs)
          .select()
          .order(AppConstants.fieldCreatedAt, ascending: false)
          .limit(limit);

      debugPrint('✅ Fetched ${response.length} audit logs');

      return response.map((json) => AuditLog.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all audit logs: $e');
      rethrow;
    }
  }

  /// Get available audit actions for filtering
  static Future<List<String>> getAvailableActions() async {
    try {
      debugPrint('🔍 Fetching available audit actions');

      final response = await _supabase
          .from(AppConstants.tableAuditLogs)
          .select(AppConstants.fieldAuditLogAction)
          .order(AppConstants.fieldAuditLogAction);

      final actions = response
          .map((json) => json[AppConstants.fieldAuditLogAction] as String)
          .toSet()
          .toList();

      debugPrint('✅ Found ${actions.length} unique actions');
      return actions;
    } catch (e) {
      debugPrint('❌ Error fetching audit actions: $e');
      return [];
    }
  }

  /// Get audit statistics using the database function
  static Future<Map<String, dynamic>> getAuditStatistics(
      String? countryId) async {
    try {
      debugPrint('🔍 Fetching audit statistics for country: $countryId');

      final response = await _supabase.rpc('get_audit_log_stats', params: {
        'target_country_id': countryId,
      });

      if (response.isEmpty) {
        return {
          'total_logs': 0,
          'unique_actions': 0,
          'unique_actors': 0,
          'logs_last_24h': 0,
          'logs_last_7d': 0,
          'logs_last_30d': 0,
          'most_common_action': null,
          'most_active_actor': null,
        };
      }

      debugPrint('✅ Fetched audit statistics');
      return response.first;
    } catch (e) {
      debugPrint('❌ Error fetching audit statistics: $e');
      return {
        'total_logs': 0,
        'unique_actions': 0,
        'unique_actors': 0,
        'logs_last_24h': 0,
        'logs_last_7d': 0,
        'logs_last_30d': 0,
        'most_common_action': null,
        'most_active_actor': null,
      };
    }
  }

  /// Check if current user can view audit logs
  static Future<bool> canViewAuditLogs() async {
    try {
      debugPrint('🔍 Checking if user can view audit logs...');

      final isSuperuser = await RoleService.isSuperuser();
      debugPrint('🔍 Is superuser: $isSuperuser');
      if (isSuperuser) return true;

      // Use the same method as home screen for consistency
      final hasAdminRole = await RoleService.hasAdminRole();
      debugPrint('🔍 Has admin role (from hasAdminRole): $hasAdminRole');
      if (hasAdminRole) return true;

      final isCountryAuditor =
          await RoleService.profileHasRole(AppConstants.roleCountryAuditor);
      debugPrint('🔍 Has country auditor role: $isCountryAuditor');
      return isCountryAuditor;
    } catch (e) {
      debugPrint('❌ Error checking audit permissions: $e');
      return false;
    }
  }

  /// Get countries that the current user can audit
  static Future<List<Map<String, dynamic>>> getAuditableCountries() async {
    try {
      debugPrint('🔍 Fetching auditable countries for current user');

      final isSuperuser = await RoleService.isSuperuser();
      if (isSuperuser) {
        debugPrint('✅ User is superuser, returning all countries');
        // Superusers can audit all countries
        final response = await _supabase
            .from(AppConstants.tableCountries)
            .select(
                '${AppConstants.fieldId}, ${AppConstants.fieldCountryName}, ${AppConstants.fieldCountryCode}')
            .eq(AppConstants.fieldCountryIsActive, true)
            .order(AppConstants.fieldCountryName);

        return [
          {'id': 'global', 'name': 'All Countries', 'country_code': 'ALL'},
          ...response
        ];
      }

      // Use the same method as the home screen for consistency
      final countries = await RoleService.getCountryAdminCountries();
      debugPrint('✅ Found ${countries.length} countries from RoleService');

      // Check if user also has auditor role for additional countries
      final isCountryAuditor =
          await RoleService.profileHasRole(AppConstants.roleCountryAuditor);
      if (isCountryAuditor) {
        debugPrint('✅ User has country auditor role');
        // For now, return the same countries. In the future, you might want to
        // get auditor-specific countries separately
      }

      return countries;
    } catch (e) {
      debugPrint('❌ Error fetching auditable countries: $e');
      return [];
    }
  }
}
