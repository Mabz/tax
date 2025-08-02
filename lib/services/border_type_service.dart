import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/border_type.dart';
import '../constants/app_constants.dart';

class BorderTypeService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all border types
  static Future<List<BorderType>> getAllBorderTypes() async {
    try {
      final response = await _supabase
          .from(AppConstants.tableBorderTypes)
          .select('*')
          .order(AppConstants.fieldBorderTypeCode);

      return response
          .map<BorderType>((json) => BorderType.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ BorderTypeService.getAllBorderTypes error: $e');
      rethrow;
    }
  }

  /// Get border type by ID
  static Future<BorderType?> getBorderTypeById(String id) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableBorderTypes)
          .select('*')
          .eq(AppConstants.fieldId, id)
          .maybeSingle();

      if (response == null) return null;
      return BorderType.fromJson(response);
    } catch (e) {
      debugPrint('❌ BorderTypeService.getBorderTypeById error: $e');
      rethrow;
    }
  }

  /// Get border type by code
  static Future<BorderType?> getBorderTypeByCode(String code) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableBorderTypes)
          .select('*')
          .eq(AppConstants.fieldBorderTypeCode, code)
          .maybeSingle();

      if (response == null) return null;
      return BorderType.fromJson(response);
    } catch (e) {
      debugPrint('❌ BorderTypeService.getBorderTypeByCode error: $e');
      rethrow;
    }
  }

  /// Create a new border type
  static Future<BorderType> createBorderType({
    required String code,
    required String label,
    String? description,
  }) async {
    try {
      final insertData = {
        AppConstants.fieldBorderTypeCode: code,
        AppConstants.fieldBorderTypeLabel: label,
        AppConstants.fieldBorderTypeDescription: description,
      };

      final response = await _supabase
          .from(AppConstants.tableBorderTypes)
          .insert(insertData)
          .select()
          .single();

      return BorderType.fromJson(response);
    } catch (e) {
      debugPrint('❌ BorderTypeService.createBorderType error: $e');
      rethrow;
    }
  }

  /// Update an existing border type
  static Future<BorderType> updateBorderType({
    required String id,
    String? code,
    String? label,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      };

      if (code != null) updateData[AppConstants.fieldBorderTypeCode] = code;
      if (label != null) updateData[AppConstants.fieldBorderTypeLabel] = label;
      if (description != null) {
        updateData[AppConstants.fieldBorderTypeDescription] = description;
      }

      final response = await _supabase
          .from(AppConstants.tableBorderTypes)
          .update(updateData)
          .eq(AppConstants.fieldId, id)
          .select()
          .single();

      return BorderType.fromJson(response);
    } catch (e) {
      debugPrint('❌ BorderTypeService.updateBorderType error: $e');
      rethrow;
    }
  }

  /// Delete a border type
  static Future<void> deleteBorderType(String id) async {
    try {
      await _supabase
          .from(AppConstants.tableBorderTypes)
          .delete()
          .eq(AppConstants.fieldId, id);
    } catch (e) {
      debugPrint('❌ BorderTypeService.deleteBorderType error: $e');
      rethrow;
    }
  }

  /// Check if border type code already exists
  static Future<bool> codeExists(String code, {String? excludeId}) async {
    try {
      var query = _supabase
          .from(AppConstants.tableBorderTypes)
          .select(AppConstants.fieldId)
          .eq(AppConstants.fieldBorderTypeCode, code);

      if (excludeId != null) {
        query = query.neq(AppConstants.fieldId, excludeId);
      }

      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ BorderTypeService.codeExists error: $e');
      return false;
    }
  }

  /// Validate border type code format
  static bool isValidCode(String code) {
    // Code should be lowercase, alphanumeric, and underscores only
    final regex = RegExp(r'^[a-z0-9_]+$');
    return code.isNotEmpty && code.length <= 20 && regex.hasMatch(code);
  }
}
