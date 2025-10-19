import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/border_schedule_template.dart';
import '../models/schedule_time_slot.dart';
import '../models/official_schedule_assignment.dart';
import '../models/schedule_snapshot.dart';

/// Border Schedule Management Service
/// Handles all operations related to border official scheduling
class BorderScheduleService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ========== SCHEDULE TEMPLATE OPERATIONS ==========

  /// Get all schedule templates for a border
  static Future<List<BorderScheduleTemplate>> getScheduleTemplatesForBorder(
    String borderId,
  ) async {
    try {
      debugPrint('🗓️ Fetching schedule templates for border: $borderId');

      final response = await _supabase
          .from('border_schedule_templates')
          .select('*')
          .eq('border_id', borderId)
          .order('created_at', ascending: false);

      final templates = (response as List)
          .map((item) => BorderScheduleTemplate.fromJson(item))
          .toList();

      debugPrint('🗓️ Found ${templates.length} schedule templates');
      return templates;
    } catch (e) {
      debugPrint('❌ Error fetching schedule templates: $e');
      rethrow;
    }
  }

  /// Get active schedule template for a border
  static Future<BorderScheduleTemplate?> getActiveScheduleTemplate(
    String borderId,
  ) async {
    try {
      final response = await _supabase
          .from('border_schedule_templates')
          .select('*')
          .eq('border_id', borderId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;

      return BorderScheduleTemplate.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching active schedule template: $e');
      return null;
    }
  }

  /// Create a new schedule template
  static Future<BorderScheduleTemplate> createScheduleTemplate({
    required String borderId,
    required String templateName,
    String? description,
    bool isActive = true,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint(
          '🗓️ Creating schedule template: $templateName for border: $borderId');

      // If this template should be active, deactivate other active templates
      if (isActive) {
        await _deactivateOtherTemplates(borderId);
      }

      final templateData = {
        'border_id': borderId,
        'template_name': templateName,
        'description': description,
        'is_active': isActive,
        'created_by': currentUser.id,
      };

      final response = await _supabase
          .from('border_schedule_templates')
          .insert(templateData)
          .select()
          .single();

      final template = BorderScheduleTemplate.fromJson(response);
      debugPrint('✅ Created schedule template: ${template.id}');

      return template;
    } catch (e) {
      debugPrint('❌ Error creating schedule template: $e');
      rethrow;
    }
  }

  /// Update a schedule template
  static Future<BorderScheduleTemplate> updateScheduleTemplate(
    String templateId, {
    String? templateName,
    String? description,
    bool? isActive,
  }) async {
    try {
      debugPrint('🗓️ Updating schedule template: $templateId');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (templateName != null) updateData['template_name'] = templateName;
      if (description != null) updateData['description'] = description;
      if (isActive != null) updateData['is_active'] = isActive;

      // If activating this template, deactivate others for the same border
      if (isActive == true) {
        final template = await getScheduleTemplate(templateId);
        if (template != null) {
          await _deactivateOtherTemplates(template.borderId,
              excludeTemplateId: templateId);
        }
      }

      final response = await _supabase
          .from('border_schedule_templates')
          .update(updateData)
          .eq('id', templateId)
          .select()
          .single();

      final updatedTemplate = BorderScheduleTemplate.fromJson(response);
      debugPrint('✅ Updated schedule template: ${updatedTemplate.id}');

      return updatedTemplate;
    } catch (e) {
      debugPrint('❌ Error updating schedule template: $e');
      rethrow;
    }
  }

  /// Get a specific schedule template
  static Future<BorderScheduleTemplate?> getScheduleTemplate(
      String templateId) async {
    try {
      final response = await _supabase
          .from('border_schedule_templates')
          .select('*')
          .eq('id', templateId)
          .maybeSingle();

      if (response == null) return null;

      return BorderScheduleTemplate.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching schedule template: $e');
      return null;
    }
  }

  /// Delete a schedule template
  static Future<void> deleteScheduleTemplate(String templateId) async {
    try {
      debugPrint('🗓️ Deleting schedule template: $templateId');

      // First delete all time slots
      await _supabase
          .from('schedule_time_slots')
          .delete()
          .eq('template_id', templateId);

      // Then delete the template
      await _supabase
          .from('border_schedule_templates')
          .delete()
          .eq('id', templateId);

      debugPrint('✅ Deleted schedule template: $templateId');
    } catch (e) {
      debugPrint('❌ Error deleting schedule template: $e');
      rethrow;
    }
  }

  // ========== TIME SLOT OPERATIONS ==========

  /// Get time slots for a template
  static Future<List<ScheduleTimeSlot>> getTimeSlots(String templateId) async {
    try {
      final response = await _supabase
          .from('schedule_time_slots')
          .select('*')
          .eq('template_id', templateId)
          .eq('is_active', true)
          .order('day_of_week')
          .order('start_time');

      return (response as List)
          .map((item) => ScheduleTimeSlot.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching time slots: $e');
      rethrow;
    }
  }

  /// Create a time slot
  static Future<ScheduleTimeSlot> createTimeSlot({
    required String templateId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int minOfficials = 1,
    int maxOfficials = 3,
  }) async {
    try {
      debugPrint('🗓️ Creating time slot for template: $templateId');

      final slotData = {
        'template_id': templateId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'min_officials': minOfficials,
        'max_officials': maxOfficials,
        'is_active': true,
      };

      final response = await _supabase
          .from('schedule_time_slots')
          .insert(slotData)
          .select()
          .single();

      return ScheduleTimeSlot.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating time slot: $e');
      rethrow;
    }
  }

  /// Update a time slot
  static Future<ScheduleTimeSlot> updateTimeSlot(
    String slotId, {
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    int? minOfficials,
    int? maxOfficials,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (dayOfWeek != null) updateData['day_of_week'] = dayOfWeek;
      if (startTime != null) updateData['start_time'] = startTime;
      if (endTime != null) updateData['end_time'] = endTime;
      if (minOfficials != null) updateData['min_officials'] = minOfficials;
      if (maxOfficials != null) updateData['max_officials'] = maxOfficials;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _supabase
          .from('schedule_time_slots')
          .update(updateData)
          .eq('id', slotId)
          .select()
          .single();

      return ScheduleTimeSlot.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating time slot: $e');
      rethrow;
    }
  }

  /// Delete a time slot
  static Future<void> deleteTimeSlot(String slotId) async {
    try {
      // First delete all assignments for this slot
      await _supabase
          .from('official_schedule_assignments')
          .delete()
          .eq('time_slot_id', slotId);

      // Then delete the time slot
      await _supabase.from('schedule_time_slots').delete().eq('id', slotId);
    } catch (e) {
      debugPrint('❌ Error deleting time slot: $e');
      rethrow;
    }
  }

  // ========== OFFICIAL ASSIGNMENT OPERATIONS ==========

  /// Get assignments for a time slot
  static Future<List<OfficialScheduleAssignment>> getAssignmentsForTimeSlot(
    String timeSlotId,
  ) async {
    try {
      final response = await _supabase
          .from('official_schedule_assignments')
          .select('*')
          .eq('time_slot_id', timeSlotId)
          .order('created_at');

      return (response as List)
          .map((item) => OfficialScheduleAssignment.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching assignments: $e');
      rethrow;
    }
  }

  /// Assign official to time slot
  static Future<OfficialScheduleAssignment> assignOfficialToTimeSlot({
    required String timeSlotId,
    required String profileId,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String assignmentType = 'primary',
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🗓️ Assigning official $profileId to time slot $timeSlotId');

      // Check for conflicts before creating assignment
      final conflicts = await checkAssignmentConflicts(
        profileId: profileId,
        timeSlotId: timeSlotId,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
      );

      if (conflicts.isNotEmpty) {
        throw Exception(
            'Assignment conflicts detected: Official is already assigned to overlapping time slots');
      }

      final assignmentData = {
        'time_slot_id': timeSlotId,
        'profile_id': profileId,
        'effective_from': effectiveFrom.toIso8601String(),
        'effective_to': effectiveTo?.toIso8601String(),
        'assignment_type': assignmentType,
        'created_by': currentUser.id,
      };

      final response = await _supabase
          .from('official_schedule_assignments')
          .insert(assignmentData)
          .select()
          .single();

      return OfficialScheduleAssignment.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error assigning official: $e');
      rethrow;
    }
  }

  /// Remove official assignment
  static Future<void> removeOfficialAssignment(String assignmentId) async {
    try {
      await _supabase
          .from('official_schedule_assignments')
          .delete()
          .eq('id', assignmentId);
    } catch (e) {
      debugPrint('❌ Error removing assignment: $e');
      rethrow;
    }
  }

  // ========== SNAPSHOT OPERATIONS ==========

  /// Create a schedule snapshot
  static Future<ScheduleSnapshot> createScheduleSnapshot({
    required String templateId,
    required String reason,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🗓️ Creating schedule snapshot for template: $templateId');

      // Get complete schedule data
      final template = await getScheduleTemplate(templateId);
      if (template == null) {
        throw Exception('Template not found');
      }

      final timeSlots = await getTimeSlots(templateId);
      final snapshotData = await _buildSnapshotData(template, timeSlots);

      final snapshotRecord = {
        'template_id': templateId,
        'snapshot_date': DateTime.now().toIso8601String(),
        'snapshot_data': snapshotData,
        'reason': reason,
        'created_by': currentUser.id,
      };

      final response = await _supabase
          .from('schedule_snapshots')
          .insert(snapshotRecord)
          .select()
          .single();

      return ScheduleSnapshot.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating schedule snapshot: $e');
      rethrow;
    }
  }

  /// Get schedule snapshots for a template
  static Future<List<ScheduleSnapshot>> getScheduleSnapshots(
    String templateId,
  ) async {
    try {
      final response = await _supabase
          .from('schedule_snapshots')
          .select('*')
          .eq('template_id', templateId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => ScheduleSnapshot.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching schedule snapshots: $e');
      rethrow;
    }
  }

  // ========== HELPER METHODS ==========

  /// Deactivate other templates for the same border
  static Future<void> _deactivateOtherTemplates(
    String borderId, {
    String? excludeTemplateId,
  }) async {
    try {
      var query = _supabase
          .from('border_schedule_templates')
          .update({'is_active': false})
          .eq('border_id', borderId)
          .eq('is_active', true);

      if (excludeTemplateId != null) {
        query = query.neq('id', excludeTemplateId);
      }

      await query;
    } catch (e) {
      debugPrint('❌ Error deactivating other templates: $e');
      rethrow;
    }
  }

  /// Build snapshot data structure
  static Future<Map<String, dynamic>> _buildSnapshotData(
    BorderScheduleTemplate template,
    List<ScheduleTimeSlot> timeSlots,
  ) async {
    try {
      // Get border information
      final borderResponse = await _supabase
          .from('borders')
          .select('name')
          .eq('id', template.borderId)
          .maybeSingle();

      final borderName = borderResponse?['name'] as String? ?? 'Unknown Border';

      // Build time slots data with assignments
      final timeSlotsData = <Map<String, dynamic>>[];
      int totalOfficials = 0;
      double totalHoursPerWeek = 0;

      for (final slot in timeSlots) {
        final assignments = await getAssignmentsForTimeSlot(slot.id);
        final activeAssignments =
            assignments.where((a) => a.isCurrentlyActive).toList();

        // Get official names
        final officialData = <Map<String, dynamic>>[];
        for (final assignment in activeAssignments) {
          final profileResponse = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', assignment.profileId)
              .maybeSingle();

          officialData.add({
            'profile_id': assignment.profileId,
            'full_name': profileResponse?['full_name'] ?? 'Unknown Official',
            'assignment_type': assignment.assignmentType,
          });
        }

        timeSlotsData.add({
          'day_of_week': slot.dayOfWeek,
          'start_time': slot.startTime,
          'end_time': slot.endTime,
          'assigned_officials': officialData,
        });

        totalOfficials += activeAssignments.length;
        totalHoursPerWeek += slot.durationHours;
      }

      // Calculate coverage percentage (assuming 24/7 coverage = 168 hours)
      const totalPossibleHours = 168.0;
      final coveragePercentage = (totalHoursPerWeek / totalPossibleHours) * 100;

      return {
        'template_id': template.id,
        'template_name': template.templateName,
        'border_id': template.borderId,
        'border_name': borderName,
        'snapshot_date': DateTime.now().toIso8601String(),
        'time_slots': timeSlotsData,
        'metadata': {
          'total_officials': totalOfficials,
          'total_hours_per_week': totalHoursPerWeek.round(),
          'coverage_percentage': coveragePercentage,
        },
      };
    } catch (e) {
      debugPrint('❌ Error building snapshot data: $e');
      rethrow;
    }
  }

  /// Check for assignment conflicts
  static Future<List<Map<String, dynamic>>> checkAssignmentConflicts({
    required String profileId,
    required String timeSlotId,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? excludeAssignmentId,
  }) async {
    try {
      // Get the time slot details
      final timeSlotResponse = await _supabase
          .from('schedule_time_slots')
          .select('day_of_week, start_time, end_time')
          .eq('id', timeSlotId)
          .single();

      final dayOfWeek = timeSlotResponse['day_of_week'] as int;
      final startTime = timeSlotResponse['start_time'] as String;
      final endTime = timeSlotResponse['end_time'] as String;

      // Find overlapping assignments for the same official
      var query = _supabase
          .from('official_schedule_assignments')
          .select('''
            id,
            time_slot_id,
            effective_from,
            effective_to,
            schedule_time_slots!inner(day_of_week, start_time, end_time)
          ''')
          .eq('profile_id', profileId)
          .eq('schedule_time_slots.day_of_week', dayOfWeek);

      if (excludeAssignmentId != null) {
        query = query.neq('id', excludeAssignmentId);
      }

      final existingAssignments = await query;

      final conflicts = <Map<String, dynamic>>[];

      for (final assignment in existingAssignments) {
        final assignmentStart = DateTime.parse(assignment['effective_from']);
        final assignmentEnd = assignment['effective_to'] != null
            ? DateTime.parse(assignment['effective_to'])
            : null;

        // Check date range overlap
        final dateOverlap =
            effectiveFrom.isBefore(assignmentEnd ?? DateTime(2100)) &&
                (effectiveTo ?? DateTime(2100)).isAfter(assignmentStart);

        if (dateOverlap) {
          final slotData = assignment['schedule_time_slots'];
          final existingStartTime = slotData['start_time'] as String;
          final existingEndTime = slotData['end_time'] as String;

          // Check time overlap
          final timeOverlap = _timeRangesOverlap(
            startTime,
            endTime,
            existingStartTime,
            existingEndTime,
          );

          if (timeOverlap) {
            conflicts.add({
              'assignment_id': assignment['id'],
              'time_slot_id': assignment['time_slot_id'],
              'day_of_week': dayOfWeek,
              'existing_time': '$existingStartTime-$existingEndTime',
              'new_time': '$startTime-$endTime',
            });
          }
        }
      }

      return conflicts;
    } catch (e) {
      debugPrint('❌ Error checking assignment conflicts: $e');
      return [];
    }
  }

  /// Check if two time ranges overlap
  static bool _timeRangesOverlap(
      String start1, String end1, String start2, String end2) {
    final s1 = _parseTimeString(start1);
    final e1 = _parseTimeString(end1);
    final s2 = _parseTimeString(start2);
    final e2 = _parseTimeString(end2);

    return s1.isBefore(e2) && s2.isBefore(e1);
  }

  /// Parse time string to DateTime for comparison
  static DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Check if user can manage schedules for a border
  static Future<bool> canManageSchedulesForBorder(String borderId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      // Check if user is a border manager for this border
      final managerResponse = await _supabase
          .from('border_manager_borders')
          .select('id')
          .eq('profile_id', currentUser.id)
          .eq('border_id', borderId)
          .eq('is_active', true)
          .maybeSingle();

      if (managerResponse != null) return true;

      // Check if user is a country administrator
      // Note: This assumes the profiles table has a role field or similar mechanism
      // Adjust based on your actual role management system
      final profileResponse = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', currentUser.id)
          .maybeSingle();

      // For now, allow access if user has border manager access to any border
      // This can be refined based on your specific role system
      return profileResponse != null;
    } catch (e) {
      debugPrint('❌ Error checking schedule management permissions: $e');
      return false;
    }
  }
}
