/// Authority service for managing revenue services, customs authorities, etc.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/authority.dart';

class AuthorityService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all authorities (superuser only)
  static Future<List<Authority>> getAllAuthorities() async {
    try {
      debugPrint('🔍 Fetching all authorities');

      final response = await _supabase.rpc('get_all_authorities');

      final authorities =
          (response as List).map((json) => Authority.fromJson(json)).toList();

      debugPrint('✅ Fetched ${authorities.length} authorities');
      return authorities;
    } catch (e) {
      debugPrint('❌ Error fetching all authorities: $e');
      rethrow;
    }
  }

  /// Get authorities for a specific country
  static Future<List<Authority>> getAuthoritiesForCountry(
      String countryId) async {
    try {
      debugPrint('🔍 Fetching authorities for country: $countryId');

      final response =
          await _supabase.rpc('get_authorities_for_country', params: {
        'target_country_id': countryId,
      });

      final authorities =
          (response as List).map((json) => Authority.fromJson(json)).toList();

      debugPrint('✅ Fetched ${authorities.length} authorities for country');
      return authorities;
    } catch (e) {
      debugPrint('❌ Error fetching authorities for country: $e');
      rethrow;
    }
  }

  /// Get authorities that the current user can administer
  static Future<List<Authority>> getAdminAuthorities() async {
    try {
      debugPrint('🔍 Fetching admin authorities for current user');

      final response = await _supabase.rpc('get_admin_authorities');

      final authorities =
          (response as List).map((json) => Authority.fromJson(json)).toList();

      debugPrint('✅ Fetched ${authorities.length} admin authorities');
      return authorities;
    } catch (e) {
      debugPrint('❌ Error fetching admin authorities: $e');
      rethrow;
    }
  }

  /// Get a single authority by ID
  static Future<Authority?> getAuthorityById(String authorityId) async {
    try {
      debugPrint('🔍 Fetching authority by ID: $authorityId');

      final response = await _supabase.rpc('get_authority_by_id', params: {
        'target_authority_id': authorityId,
      });

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('❌ Authority not found: $authorityId');
        return null;
      }

      // Handle both JSON object and table row responses
      Map<String, dynamic> authorityData;
      if (response is List && response.isNotEmpty) {
        authorityData = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        authorityData = response;
      } else {
        debugPrint('❌ Unexpected response format for authority: $authorityId');
        return null;
      }

      final authority = Authority.fromJson(authorityData);
      debugPrint('✅ Fetched authority: ${authority.name}');
      return authority;
    } catch (e) {
      debugPrint('❌ Error fetching authority by ID: $e');
      return null;
    }
  }

  /// Create a new authority
  static Future<String> createAuthority({
    required String countryId,
    required String name,
    required String code,
    required String authorityType,
    String? description,
    int defaultPassAdvanceDays = 30,
    String? defaultCurrencyCode,
    bool isActive = true,
  }) async {
    try {
      debugPrint('🔍 Creating authority: $name ($code)');

      final response = await _supabase.rpc('create_authority', params: {
        'target_country_id': countryId,
        'authority_name': name,
        'authority_code': code,
        'authority_type': authorityType,
        'authority_description': description,
        'authority_default_pass_advance_days': defaultPassAdvanceDays,
        'authority_default_currency_code': defaultCurrencyCode,
        'authority_is_active': isActive,
      });

      final authorityId = response as String;
      debugPrint('✅ Created authority with ID: $authorityId');
      return authorityId;
    } catch (e) {
      debugPrint('❌ Error creating authority: $e');
      rethrow;
    }
  }

  /// Update an existing authority
  static Future<void> updateAuthority({
    required String authorityId,
    required String name,
    required String code,
    required String authorityType,
    String? description,
    int defaultPassAdvanceDays = 30,
    String? defaultCurrencyCode,
    required bool isActive,
  }) async {
    try {
      debugPrint('🔍 Updating authority: $authorityId');

      await _supabase.rpc('update_authority', params: {
        'target_authority_id': authorityId,
        'new_name': name,
        'new_code': code,
        'new_authority_type': authorityType,
        'new_description': description,
        'new_default_pass_advance_days': defaultPassAdvanceDays,
        'new_default_currency_code': defaultCurrencyCode,
        'new_is_active': isActive,
      });

      debugPrint('✅ Updated authority: $authorityId');
    } catch (e) {
      debugPrint('❌ Error updating authority: $e');
      rethrow;
    }
  }

  /// Delete an authority (soft delete by setting inactive)
  static Future<void> deleteAuthority(String authorityId) async {
    try {
      debugPrint('🔍 Deleting authority: $authorityId');

      await _supabase.rpc('delete_authority', params: {
        'target_authority_id': authorityId,
      });

      debugPrint('✅ Deleted authority: $authorityId');
    } catch (e) {
      debugPrint('❌ Error deleting authority: $e');
      rethrow;
    }
  }

  /// Check if authority code exists (for validation)
  static Future<bool> authorityCodeExists(String countryId, String code,
      {String? excludeId}) async {
    try {
      debugPrint('🔍 Checking if authority code exists: $code');

      final response = await _supabase.rpc('authority_code_exists', params: {
        'target_country_id': countryId,
        'target_code': code,
        'exclude_authority_id': excludeId,
      });

      final exists = response as bool;
      debugPrint('✅ Authority code exists: $exists');
      return exists;
    } catch (e) {
      debugPrint('❌ Error checking authority code: $e');
      return false;
    }
  }

  /// Get available authority types
  static List<Map<String, String>> getAuthorityTypes() {
    return [
      {'value': 'revenue_service', 'label': 'Revenue Service'},
      {'value': 'customs', 'label': 'Customs Authority'},
      {'value': 'immigration', 'label': 'Immigration Authority'},
      {'value': 'global', 'label': 'Global Authority'},
    ];
  }

  /// Get authorities for operational roles (border officials and local authorities)
  static Future<List<Authority>> getOperationalAuthorities() async {
    try {
      debugPrint('🔍 Fetching operational authorities for current user');

      // Try to use the admin authorities function first, as it might work for operational roles too
      try {
        final response = await _supabase.rpc('get_admin_authorities');
        final authorities =
            (response as List).map((json) => Authority.fromJson(json)).toList();

        if (authorities.isNotEmpty) {
          debugPrint(
              '✅ Fetched ${authorities.length} operational authorities via admin function');
          return authorities;
        }
      } catch (e) {
        debugPrint(
            '⚠️ Admin authorities function failed for operational role: $e');
      }

      // Fallback: Get authorities based on user's profile_roles
      debugPrint('🔄 Falling back to direct profile_roles query');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('❌ No authenticated user');
        return [];
      }

      final response = await _supabase
          .from('profile_roles')
          .select('''
            authorities!inner(
              id,
              country_id,
              name,
              code,
              authority_type,
              description,
              is_active,
              default_pass_advance_days,
              default_currency_code,
              created_at,
              updated_at,
              countries!inner(
                id,
                name,
                country_code,
                is_active,
                is_global,
                created_at,
                updated_at
              )
            )
          ''')
          .eq('profile_id', user.id)
          .eq('is_active', true)
          .eq('authorities.is_active', true)
          .eq('authorities.countries.is_active', true)
          .neq('authorities.authority_type', 'global')
          .neq('authorities.countries.is_global', true);

      final authorities = <Authority>[];
      final seenAuthorityIds = <String>{};

      for (final item in response) {
        final authorityData = item['authorities'] as Map<String, dynamic>;
        final authorityId = authorityData['id'] as String;

        // Avoid duplicates
        if (seenAuthorityIds.contains(authorityId)) continue;
        seenAuthorityIds.add(authorityId);

        final countryData = authorityData['countries'] as Map<String, dynamic>;

        // Create authority with country information
        final authority = Authority(
          id: authorityId,
          countryId: authorityData['country_id'] as String,
          name: authorityData['name'] as String,
          code: authorityData['code'] as String,
          authorityType: authorityData['authority_type'] as String,
          description: authorityData['description'] as String?,
          isActive: authorityData['is_active'] as bool,
          defaultPassAdvanceDays:
              authorityData['default_pass_advance_days'] as int? ?? 30,
          defaultCurrencyCode:
              authorityData['default_currency_code'] as String?,
          createdAt: DateTime.parse(authorityData['created_at'] as String),
          updatedAt: DateTime.parse(authorityData['updated_at'] as String),
          countryName: countryData['name'] as String,
          countryCode: countryData['country_code'] as String,
        );

        authorities.add(authority);
      }

      debugPrint(
          '✅ Fetched ${authorities.length} operational authorities via fallback');
      return authorities;
    } catch (e) {
      debugPrint('❌ Error fetching operational authorities: $e');
      return [];
    }
  }

  /// Get authority statistics
  static Future<Map<String, dynamic>> getAuthorityStats(
      String authorityId) async {
    try {
      debugPrint('🔍 Fetching authority statistics: $authorityId');

      final response = await _supabase.rpc('get_authority_stats', params: {
        'target_authority_id': authorityId,
      });

      debugPrint('✅ Fetched authority statistics');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error fetching authority statistics: $e');
      return {};
    }
  }

  /// Get all countries (superuser only)
  static Future<List<Map<String, dynamic>>> getAllCountries() async {
    try {
      debugPrint('🔍 Fetching all countries');

      final response = await _supabase.rpc('get_all_countries');

      final countries = (response as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();

      debugPrint('✅ Fetched ${countries.length} countries');
      return countries;
    } catch (e) {
      debugPrint('❌ Error fetching countries: $e');
      return [];
    }
  }
}
