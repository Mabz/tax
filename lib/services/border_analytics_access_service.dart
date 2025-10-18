import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manage access control for Border Analytics screen
class BorderAnalyticsAccessService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if current user can access Border Analytics
  static Future<bool> canAccessBorderAnalytics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Get user roles
      final response = await _supabase
          .from('profile_roles')
          .select('roles!inner(name), authorities(id, name)')
          .eq('profile_id', user.id)
          .eq('is_active', true);

      final userRoles = response as List<dynamic>;

      // Check if user has any of the allowed roles
      final allowedRoles = {
        'country_admin',
        'country_auditor',
        'compliance_officer',
        'border_manager',
        'superuser'
      };

      for (final roleData in userRoles) {
        final roleName = roleData['roles']['name'] as String;
        if (allowedRoles.contains(roleName)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking border analytics access: $e');
      return false;
    }
  }

  /// Get authorities that the current user can access for border analytics
  static Future<List<Map<String, dynamic>>> getAccessibleAuthorities() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Get user roles with authorities
      final response = await _supabase.from('profile_roles').select('''
            roles!inner(name), 
            authorities(
              id, 
              name, 
              code,
              countries(name, country_code)
            )
          ''').eq('profile_id', user.id).eq('is_active', true);

      final userRoles = response as List<dynamic>;
      final authorities = <String, Map<String, dynamic>>{};

      // Collect unique authorities based on user roles
      for (final roleData in userRoles) {
        final roleName = roleData['roles']['name'] as String;
        final authority = roleData['authorities'] as Map<String, dynamic>?;

        if (authority != null) {
          final allowedRoles = {
            'country_admin',
            'country_auditor',
            'compliance_officer',
            'border_manager',
            'superuser'
          };

          if (allowedRoles.contains(roleName)) {
            final authorityId = authority['id'] as String;
            authorities[authorityId] = {
              'id': authorityId,
              'name': authority['name'],
              'code': authority['code'],
              'country_name': authority['countries']?['name'] ?? 'Unknown',
              'country_code': authority['countries']?['country_code'] ?? '',
              'user_role': roleName,
            };
          }
        }
      }

      return authorities.values.toList();
    } catch (e) {
      debugPrint('❌ Error getting accessible authorities: $e');
      return [];
    }
  }

  /// Check if user has specific role for an authority
  static Future<bool> hasRoleForAuthority(
      String authorityId, List<String> requiredRoles) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('profile_roles')
          .select('roles!inner(name)')
          .eq('profile_id', user.id)
          .eq('authority_id', authorityId)
          .eq('is_active', true);

      final userRoles = response as List<dynamic>;

      for (final roleData in userRoles) {
        final roleName = roleData['roles']['name'] as String;
        if (requiredRoles.contains(roleName)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking role for authority: $e');
      return false;
    }
  }

  /// Get user's role display name for UI
  static String getRoleDisplayName(String roleName) {
    switch (roleName) {
      case 'country_admin':
        return 'Country Administrator';
      case 'country_auditor':
        return 'Country Auditor';
      case 'compliance_officer':
        return 'Compliance Officer';
      case 'border_manager':
        return 'Border Manager';
      case 'superuser':
        return 'System Administrator';
      default:
        return roleName.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Get role-based permissions for analytics features
  static Map<String, bool> getRolePermissions(String roleName) {
    switch (roleName) {
      case 'country_admin':
        return {
          'view_all_borders': true,
          'view_revenue': true,
          'view_compliance': true,
          'view_alerts': true,
          'export_data': true,
          'manage_settings': true,
        };
      case 'country_auditor':
        return {
          'view_all_borders': true,
          'view_revenue': true,
          'view_compliance': true,
          'view_alerts': true,
          'export_data': true,
          'manage_settings': false,
        };
      case 'compliance_officer':
        return {
          'view_all_borders': true,
          'view_revenue': false,
          'view_compliance': true,
          'view_alerts': true,
          'export_data': true,
          'manage_settings': false,
        };
      case 'border_manager':
        return {
          'view_all_borders': false, // Only assigned borders
          'view_revenue': true,
          'view_compliance': true,
          'view_alerts': true,
          'export_data': false,
          'manage_settings': false,
        };
      case 'superuser':
        return {
          'view_all_borders': true,
          'view_revenue': true,
          'view_compliance': true,
          'view_alerts': true,
          'export_data': true,
          'manage_settings': true,
        };
      default:
        return {
          'view_all_borders': false,
          'view_revenue': false,
          'view_compliance': false,
          'view_alerts': false,
          'export_data': false,
          'manage_settings': false,
        };
    }
  }
}
