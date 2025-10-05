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

      // Start with the simplest possible query to test connectivity
      List<Map<String, dynamic>> response;

      try {
        // Try basic query first
        debugPrint('🔍 Trying basic authorities query...');
        response = await _supabase
            .from('authorities')
            .select(
                'id, name, country_id, code, authority_type, description, is_active, created_at, updated_at')
            .eq('is_active', true)
            .order('name');

        debugPrint(
            '✅ Basic query successful, got ${response.length} authorities');

        // Now try to add country information
        debugPrint('🔍 Trying query with country join...');
        response = await _supabase
            .from('authorities')
            .select('''
              id,
              country_id,
              name,
              code,
              authority_type,
              description,
              is_active,
              default_currency,
              created_at,
              updated_at,
              countries!inner(
                id,
                name,
                country_code,
                is_active
              )
            ''')
            .eq('is_active', true)
            .eq('countries.is_active', true)
            .order('name');

        debugPrint(
            '✅ Country join query successful, got ${response.length} authorities');
      } catch (queryError) {
        debugPrint('⚠️ Advanced query failed: $queryError');
        debugPrint('🔄 Falling back to basic query without country join...');

        // Fallback to basic query without country join
        response = await _supabase
            .from('authorities')
            .select(
                'id, name, country_id, code, authority_type, description, is_active, default_currency, created_at, updated_at')
            .eq('is_active', true)
            .order('name');

        debugPrint(
            '✅ Fallback query successful, got ${response.length} authorities');
      }

      if (response.isEmpty) {
        debugPrint('⚠️ No authorities found in database');
        return [];
      }

      final authorities = <Authority>[];

      for (final json in response) {
        try {
          // Handle both nested and flat country data
          if (json.containsKey('countries')) {
            final countryData = json['countries'] as Map<String, dynamic>;
            final flattenedJson = Map<String, dynamic>.from(json);
            flattenedJson['country_name'] = countryData['name'];
            flattenedJson['country_code'] = countryData['country_code'];
            flattenedJson.remove('countries');
            authorities.add(Authority.fromJson(flattenedJson));
          } else {
            // No country data available, create authority without it
            authorities.add(Authority.fromJson(json));
          }
        } catch (parseError) {
          debugPrint('⚠️ Error parsing authority JSON: $parseError');
          debugPrint('⚠️ Problematic JSON: $json');
          // Continue with other authorities
        }
      }

      debugPrint('✅ Successfully parsed ${authorities.length} authorities');
      return authorities;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching all authorities: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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

      // Try the RPC function first
      try {
        final response = await _supabase.rpc('get_admin_authorities');
        final authorities =
            (response as List).map((json) => Authority.fromJson(json)).toList();

        debugPrint('✅ Fetched ${authorities.length} admin authorities via RPC');
        return authorities;
      } catch (rpcError) {
        debugPrint('⚠️ Admin authorities RPC function failed: $rpcError');
      }

      // Fallback: Get authorities based on user's profile_roles for admin roles
      debugPrint(
          '🔄 Falling back to direct profile_roles query for admin authorities');

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
              created_at,
              updated_at,
              countries!inner(
                id,
                name,
                country_code,
                is_active
              )
            ),
            roles!inner(
              name
            )
          ''')
          .eq('profile_id', user.id)
          .eq('is_active', true)
          .eq('authorities.is_active', true)
          .eq('authorities.countries.is_active', true)
          .inFilter('roles.name', ['country_admin', 'country_auditor']);

      final authorities = response.map<Authority>((item) {
        final authority = item['authorities'] as Map<String, dynamic>;
        final country = authority['countries'] as Map<String, dynamic>;

        // Flatten the data for the Authority model
        final flattenedJson = Map<String, dynamic>.from(authority);
        flattenedJson['country_name'] = country['name'];
        flattenedJson['country_code'] = country['country_code'];
        flattenedJson.remove('countries');

        return Authority.fromJson(flattenedJson);
      }).toList();

      // Remove duplicates by authority ID
      final uniqueAuthorities = <String, Authority>{};
      for (final authority in authorities) {
        uniqueAuthorities[authority.id] = authority;
      }

      final result = uniqueAuthorities.values.toList();
      debugPrint('✅ Fetched ${result.length} admin authorities via fallback');
      return result;
    } catch (e) {
      debugPrint('❌ Error fetching admin authorities: $e');
      rethrow;
    }
  }

  /// Get a single authority by ID
  static Future<Authority?> getAuthorityById(String authorityId) async {
    try {
      debugPrint('🔍 AuthorityService: Fetching authority by ID: $authorityId');

      // Try RPC function first
      try {
        final response = await _supabase.rpc('get_authority_by_id', params: {
          'target_authority_id': authorityId,
        });

        debugPrint(
            '🔍 AuthorityService: RPC response type: ${response.runtimeType}');
        debugPrint('🔍 AuthorityService: RPC response: $response');

        if (response != null && response is List && response.isNotEmpty) {
          final authorityData = response.first as Map<String, dynamic>;
          debugPrint('🔍 AuthorityService: Using RPC response data');
          debugPrint('🔍 AuthorityService: Authority data: $authorityData');

          final authority = Authority.fromJson(authorityData);
          debugPrint(
              '✅ AuthorityService: Successfully parsed authority via RPC: ${authority.name}');
          return authority;
        } else if (response != null && response is Map<String, dynamic>) {
          debugPrint('🔍 AuthorityService: Using direct RPC map response');
          debugPrint('🔍 AuthorityService: Authority data: $response');

          final authority = Authority.fromJson(response);
          debugPrint(
              '✅ AuthorityService: Successfully parsed authority via RPC: ${authority.name}');
          return authority;
        } else {
          debugPrint(
              '⚠️ AuthorityService: RPC returned null or empty, trying direct query');
        }
      } catch (rpcError) {
        debugPrint(
            '⚠️ AuthorityService: RPC get_authority_by_id failed: $rpcError');
        debugPrint(
            '🔄 AuthorityService: Falling back to direct table query...');
      }

      // Fallback to direct table query
      debugPrint(
          '🔍 AuthorityService: Trying direct table query for authority: $authorityId');

      // Try to get authority with optional columns first
      Map<String, dynamic> response;
      try {
        response = await _supabase.from('authorities').select('''
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
              country_code
            )
          ''').eq('id', authorityId).eq('is_active', true).single();
        debugPrint(
            '✅ AuthorityService: Retrieved authority with optional columns');
      } catch (columnError) {
        debugPrint(
            '⚠️ AuthorityService: Optional columns failed, trying basic query: $columnError');
        response = await _supabase.from('authorities').select('''
            id,
            country_id,
            name,
            code,
            authority_type,
            description,
            is_active,
            created_at,
            updated_at,
            countries!inner(
              id,
              name,
              country_code
            )
          ''').eq('id', authorityId).eq('is_active', true).single();
        debugPrint(
            '✅ AuthorityService: Retrieved authority with basic columns');
      }

      debugPrint('🔍 AuthorityService: Direct query response: $response');

      if (response.isEmpty) {
        debugPrint(
            '❌ AuthorityService: Authority not found in direct query: $authorityId');
        return null;
      }

      // Handle nested country data
      final authorityData = Map<String, dynamic>.from(response);
      if (authorityData.containsKey('countries')) {
        final countryData = authorityData['countries'] as Map<String, dynamic>;
        authorityData['country_name'] = countryData['name'];
        authorityData['country_code'] = countryData['country_code'];
        authorityData.remove('countries');
      }

      debugPrint(
          '🔍 AuthorityService: Processed authority data: $authorityData');

      final authority = Authority.fromJson(authorityData);
      debugPrint(
          '✅ AuthorityService: Successfully parsed authority via direct query: ${authority.name}');
      debugPrint(
          '🔍 AuthorityService: Authority details - ID: ${authority.id}, Name: ${authority.name}, Description: ${authority.description}');
      return authority;
    } catch (e, stackTrace) {
      debugPrint('❌ AuthorityService: Error fetching authority by ID: $e');
      debugPrint('❌ AuthorityService: Stack trace: $stackTrace');

      // Last resort: try basic query without country join
      try {
        debugPrint(
            '🔄 AuthorityService: Trying basic query without country join...');

        final response = await _supabase
            .from('authorities')
            .select(
                'id, country_id, name, code, authority_type, description, is_active, created_at, updated_at')
            .eq('id', authorityId)
            .eq('is_active', true)
            .single();

        debugPrint('🔍 AuthorityService: Basic query response: $response');

        if (response.isNotEmpty) {
          final authority = Authority.fromJson(response);
          debugPrint(
              '✅ AuthorityService: Successfully parsed authority via basic query: ${authority.name}');
          return authority;
        }
      } catch (basicError) {
        debugPrint('❌ AuthorityService: Basic query also failed: $basicError');
      }

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

      // Try RPC function first
      try {
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
        debugPrint('✅ Created authority with ID: $authorityId via RPC');
        return authorityId;
      } catch (rpcError) {
        debugPrint('⚠️ RPC create_authority failed: $rpcError');
        debugPrint('🔄 Falling back to direct table insert...');

        // Fallback to direct table insert
        // Try with all columns first, then fall back to basic columns
        Map<String, dynamic> insertData = {
          'country_id': countryId,
          'name': name,
          'code': code,
          'authority_type': authorityType,
          'description': description,
          'is_active': isActive,
        };

        // Try to add optional columns if they exist
        try {
          insertData['default_pass_advance_days'] = defaultPassAdvanceDays;
          insertData['default_currency_code'] = defaultCurrencyCode;

          final response = await _supabase
              .from('authorities')
              .insert(insertData)
              .select('id')
              .single();

          final authorityId = response['id'] as String;
          debugPrint(
              '✅ Created authority with ID: $authorityId via direct insert (full)');
          return authorityId;
        } catch (columnError) {
          debugPrint('⚠️ Full column insert failed: $columnError');
          debugPrint('🔄 Trying basic columns only...');

          // Remove optional columns and try again
          insertData.remove('default_pass_advance_days');
          insertData.remove('default_currency_code');

          final response = await _supabase
              .from('authorities')
              .insert(insertData)
              .select('id')
              .single();

          final authorityId = response['id'] as String;
          debugPrint(
              '✅ Created authority with ID: $authorityId via direct insert (basic)');
          return authorityId;
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating authority: $e');
      rethrow;
    }
  }

  /// Check if optional columns exist in authorities table
  static Future<bool> _checkOptionalColumnsExist() async {
    try {
      debugPrint('🔍 Checking if optional columns exist in authorities table');

      // Try to query a single row with optional columns
      final response = await _supabase
          .from('authorities')
          .select('default_pass_advance_days, default_currency_code')
          .limit(1);

      debugPrint(
          '✅ Optional columns (default_pass_advance_days, default_currency_code) exist in authorities table');
      return true;
    } catch (e) {
      debugPrint(
          '❌ Optional columns (default_pass_advance_days, default_currency_code) do not exist in authorities table: $e');
      debugPrint(
          '💡 This means the database schema needs to be updated to support these fields');
      return false;
    }
  }

  /// Update an existing authority
  static Future<void> updateAuthority({
    required String authorityId,
    required String name,
    required String code,
    required String authorityType,
    String? description,
    int? defaultPassAdvanceDays,
    String? defaultCurrencyCode,
    bool? isActive,
  }) async {
    try {
      debugPrint('🔍 Updating authority: $authorityId');
      debugPrint('🔍 Default pass advance days: $defaultPassAdvanceDays');

      // Check if optional columns exist first
      final optionalColumnsExist = await _checkOptionalColumnsExist();

      // Try RPC function first
      try {
        final rpcParams = <String, dynamic>{
          'target_authority_id': authorityId,
          'new_name': name,
          'new_code': code,
          'new_authority_type': authorityType,
          'new_description': description,
        };

        if (defaultPassAdvanceDays != null) {
          rpcParams['new_default_pass_advance_days'] = defaultPassAdvanceDays;
          debugPrint(
              '🔍 Adding advance days to RPC params: $defaultPassAdvanceDays');
        }
        if (defaultCurrencyCode != null) {
          rpcParams['new_default_currency_code'] = defaultCurrencyCode;
        }
        if (isActive != null) {
          rpcParams['new_is_active'] = isActive;
        }

        debugPrint('🔍 RPC params: $rpcParams');
        await _supabase.rpc('update_authority', params: rpcParams);

        debugPrint('✅ Updated authority: $authorityId via RPC');
      } catch (rpcError) {
        debugPrint('⚠️ RPC update_authority failed: $rpcError');
        debugPrint('🔄 Falling back to direct table update...');

        // Fallback to direct table update
        // Try with all columns first, then fall back to basic columns
        Map<String, dynamic> updateData = {
          'name': name,
          'code': code,
          'authority_type': authorityType,
          'description': description,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Add optional parameters if provided
        if (isActive != null) {
          updateData['is_active'] = isActive;
        }

        // Add optional columns only if they exist in the database
        if (optionalColumnsExist) {
          if (defaultPassAdvanceDays != null) {
            updateData['default_pass_advance_days'] = defaultPassAdvanceDays;
            debugPrint(
                '🔍 Adding advance days to direct update: $defaultPassAdvanceDays');
          }
          if (defaultCurrencyCode != null) {
            updateData['default_currency_code'] = defaultCurrencyCode;
          }
        } else {
          debugPrint(
              '⚠️ Skipping optional columns as they do not exist in the database');
          if (defaultPassAdvanceDays != null) {
            debugPrint(
                '⚠️ Cannot save default_pass_advance_days: $defaultPassAdvanceDays - column does not exist');
          }
          if (defaultCurrencyCode != null) {
            debugPrint(
                '⚠️ Cannot save default_currency_code: $defaultCurrencyCode - column does not exist');
          }
        }

        debugPrint('🔍 Direct update data: $updateData');
        await _supabase
            .from('authorities')
            .update(updateData)
            .eq('id', authorityId);
        debugPrint('✅ Updated authority: $authorityId via direct update');

        debugPrint('✅ Updated authority: $authorityId via direct update');
      }
    } catch (e) {
      debugPrint('❌ Error updating authority: $e');
      rethrow;
    }
  }

  /// Disable an authority (soft delete by setting is_active = false)
  /// This preserves all authority data while making it unavailable for new operations.
  /// The authority can be reactivated by updating is_active = true.
  static Future<void> deleteAuthority(String authorityId) async {
    try {
      debugPrint('🔍 Deleting authority: $authorityId');

      // Try RPC function first
      try {
        await _supabase.rpc('delete_authority', params: {
          'target_authority_id': authorityId,
        });

        debugPrint('✅ Deleted authority: $authorityId via RPC');
      } catch (rpcError) {
        debugPrint('⚠️ RPC delete_authority failed: $rpcError');
        debugPrint('🔄 Falling back to direct table update (soft delete)...');

        // Fallback to direct table update (soft delete by setting inactive)
        await _supabase.from('authorities').update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', authorityId);

        debugPrint(
            '✅ Deleted authority: $authorityId via direct update (soft delete)');
      }
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

      // Try RPC function first
      try {
        final response = await _supabase.rpc('authority_code_exists', params: {
          'target_country_id': countryId,
          'target_code': code,
          'exclude_authority_id': excludeId,
        });

        final exists = response as bool;
        debugPrint('✅ Authority code exists: $exists via RPC');
        return exists;
      } catch (rpcError) {
        debugPrint('⚠️ RPC authority_code_exists failed: $rpcError');
        debugPrint('🔄 Falling back to direct table query...');

        // Fallback to direct table query
        var query = _supabase
            .from('authorities')
            .select('id')
            .eq('country_id', countryId)
            .eq('code', code)
            .eq('is_active', true);

        if (excludeId != null) {
          query = query.neq('id', excludeId);
        }

        final response = await query;
        final exists = (response as List).isNotEmpty;
        debugPrint('✅ Authority code exists: $exists via direct query');
        return exists;
      }
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

      // Try the operational authorities RPC function first
      try {
        final response = await _supabase.rpc('get_operational_authorities');
        final authorities =
            (response as List).map((json) => Authority.fromJson(json)).toList();

        debugPrint(
            '✅ Fetched ${authorities.length} operational authorities via RPC');
        return authorities;
      } catch (rpcError) {
        debugPrint('⚠️ Operational authorities RPC function failed: $rpcError');
      }

      // Fallback: Get authorities based on user's profile_roles for operational roles
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
              created_at,
              updated_at,
              countries!inner(
                id,
                name,
                country_code,
                is_active
              )
            ),
            roles!inner(
              name
            )
          ''')
          .eq('profile_id', user.id)
          .eq('is_active', true)
          .eq('authorities.is_active', true)
          .eq('authorities.countries.is_active', true)
          .inFilter('roles.name',
              ['border_official', 'local_authority', 'business_intelligence']);

      final authorities = response.map<Authority>((item) {
        final authority = item['authorities'] as Map<String, dynamic>;
        final country = authority['countries'] as Map<String, dynamic>;

        // Flatten the data for the Authority model
        final flattenedJson = Map<String, dynamic>.from(authority);
        flattenedJson['country_name'] = country['name'];
        flattenedJson['country_code'] = country['country_code'];
        flattenedJson.remove('countries');

        return Authority.fromJson(flattenedJson);
      }).toList();

      // Remove duplicates by authority ID
      final uniqueAuthorities = <String, Authority>{};
      for (final authority in authorities) {
        uniqueAuthorities[authority.id] = authority;
      }

      final result = uniqueAuthorities.values.toList();
      debugPrint(
          '✅ Fetched ${result.length} operational authorities via fallback');
      return result;
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

      // Try RPC function first
      try {
        final response = await _supabase.rpc('get_all_countries');
        final countries = (response as List)
            .map((json) => json as Map<String, dynamic>)
            .toList();
        debugPrint('✅ Fetched ${countries.length} countries via RPC');
        return countries;
      } catch (rpcError) {
        debugPrint('⚠️ RPC get_all_countries failed: $rpcError');
        debugPrint('🔄 Falling back to direct table query...');

        // Fallback to direct table query
        final response = await _supabase
            .from('countries')
            .select('id, name, country_code, is_active')
            .eq('is_active', true)
            .order('name');

        final countries = (response as List)
            .map((json) => json as Map<String, dynamic>)
            .toList();

        debugPrint('✅ Fetched ${countries.length} countries via direct query');
        return countries;
      }
    } catch (e) {
      debugPrint('❌ Error fetching countries: $e');
      return [];
    }
  }
}
